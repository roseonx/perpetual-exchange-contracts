// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IPositionHandler.sol";
import "./interfaces/IPositionKeeper.sol";
import "./interfaces/ISettingsManager.sol";
import "./interfaces/IPriceManager.sol";
import "./interfaces/IVaultUtils.sol";
import "./BasePosition.sol";

pragma solidity ^0.8.12;

abstract contract BaseRouter is BasePosition {
    IVault public vault;
    IVaultUtils public vaultUtils;

    event SetVault(address vault);
    event SetVaultUtils(address vaultUtils);

    constructor(
        address _vault, 
        address _positionHandler, 
        address _positionKeeper,
        address _settingsManager,
        address _priceManager,
        address _vaultUtils
    ) BasePosition(_settingsManager, _priceManager) {
        _setVault(_vault);
        _setVaultUtils(_vaultUtils);
        _setPositionHandler(_positionHandler);
        _setPositionKeeper(_positionKeeper);
    }

    function setVault(address _vault) external onlyOwner {
        _setVault(_vault);
    }

    function setVaultUtils(address _vaultUtils) external onlyOwner {
        _setVaultUtils(_vaultUtils);
    }

    function _setVault(address _vault) private {
        vault = IVault(_vault);
        emit SetVault(_vault);
    }

    function _setVaultUtils(address _vaultUtils) private {
        vaultUtils = IVaultUtils(_vaultUtils);
        emit SetVaultUtils(_vaultUtils);
    }
}