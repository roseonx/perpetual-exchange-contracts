// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/ISettingsManager.sol";
import "./interfaces/IPriceManager.sol";
import "./interfaces/IPositionHandler.sol";
import "./interfaces/IPositionKeeper.sol";

import "../constants/PositionConstants.sol";
import "../access/BaseExecutor.sol";

contract BasePosition is PositionConstants, BaseExecutor {
    ISettingsManager public settingsManager;
    IPriceManager public priceManager;
    IPositionHandler public positionHandler;
    IPositionKeeper public positionKeeper;

    constructor(
        address _settingsManager, 
        address _priceManager
    ) {
        settingsManager = ISettingsManager(_settingsManager);
        priceManager = IPriceManager(_priceManager);
    }

    event SetSettingsManager(address settingsManager);
    event SetPriceManager(address priceManager);
    event SetPositionHandler(address positionHandler);
    event SetPositionKeeper(address positionKeeper);

    //Config functions
    function setPositionHandler(address _positionHandler) external onlyOwner {
        _setPositionHandler(_positionHandler);
    }

    function setPositionKeeper(address _positionKeeper) external onlyOwner {
        _setPositionKeeper(_positionKeeper);
    }

    function setSettingsManager(address _settingsManager) external onlyOwner {
        _setSettingsManager(_settingsManager);
    }

    function setPriceManager(address _priceManager) external onlyOwner {
        _setPriceManager(_priceManager);
    }

    //End config functions

    function _setSettingsManager(address _settingsManager) internal {
        settingsManager = ISettingsManager(_settingsManager);
        emit SetSettingsManager(_settingsManager);
    }

    function _setPriceManager(address _priceManager) internal {
        priceManager = IPriceManager(_priceManager);
        emit SetPriceManager(_priceManager);
    }

    function _setPositionHandler(address _positionHandler) internal {
        positionHandler = IPositionHandler(_positionHandler);
        emit SetPositionHandler(_positionHandler);
    }

    function _setPositionKeeper(address _positionKeeper) internal {
        positionKeeper = IPositionKeeper(_positionKeeper);
        emit SetPositionKeeper(_positionKeeper);
    }

    function _prevalidate(address _indexToken) internal view {
        _validateInitialized();
        require(settingsManager.marketOrderEnabled(), "SM/MOD"); //Market order disabled
        require(settingsManager.isTradable(_indexToken), "SM/NAT"); //Not tradable token
    }

    function _validateInitialized() internal view {
        _validateSettingsManager();
        _validatePriceManager();
        _validatePositionHandler();
        _validatePositionKeeper();
    }

    function _validateSettingsManager() internal view {
        require(address(settingsManager) != address(0), "NI/SM"); //SettingsManager not initialized
    }

    function _validatePriceManager() internal view {
        require(address(priceManager) != address(0), "NI/PM"); //PriceManager not initialized
    }

    function _validatePositionHandler() internal view {
        require(address(positionHandler) != address(0), "NI/PH"); //PositionHandler not initialized
    }

    function _validatePositionKeeper() internal view {
        require(address(positionKeeper) != address(0), "NI/PK"); //PositionKeeper not intialized
    }

    function _getPriceAndCheckFastExecute(address _indexToken) internal view returns (bool, uint256) {
        (uint256 price, , bool isFastExecute) = priceManager.getLatestSynchronizedPrice(_indexToken);
        return (isFastExecute, price);
    }

    function _getPricesAndCheckFastExecute(address[] memory _path) internal view returns (bool, uint256[] memory) {
        require(_path.length >= 1 && _path.length <= 3, "IVLPTL");
        bool isFastExecute;
        uint256[] memory prices;

        {
            (prices, isFastExecute) = priceManager.getLatestSynchronizedPrices(_path);
        }

        return (isFastExecute, prices);
    }
}