// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IPositionKeeper.sol";
import "./interfaces/IPositionHandler.sol";
import "./interfaces/IPriceManager.sol";
import "./interfaces/ISettingsManager.sol";
import "./interfaces/IRouter.sol";
import "../tokens/interfaces/IMintable.sol";

import  "../constants/BasePositionConstants.sol";
import {PositionBond} from "../constants/Structs.sol";

contract PositionKeeper is BasePositionConstants, IPositionKeeper, ReentrancyGuard, Ownable {
    address public router;
    address public positionHandler;
    address public settingsManager;

    mapping(address => uint256) public override lastPositionIndex;
    mapping(bytes32 => Position) public positions;
    mapping(bytes32 => OrderInfo) public orders;
    mapping(bytes32 => FinalPath) public finalPaths;

    mapping(address => mapping(bool => uint256)) public override poolAmounts;
    mapping(address => mapping(bool => uint256)) public override reservedAmounts;

    struct FinalPath {
        address indexToken;
        address collateralToken;
    }

    event SetRouter(address router);
    event SetPositionHandler(address positionHandler);
    event SetSettingsManager(address settingsManager);
    event NewOrder(
        bytes32 key,
        address indexed account,
        bool isLong,
        uint256 posId,
        uint256 positionType,
        OrderStatus orderStatus,
        address[] path,
        uint256 collateralIndex,
        uint256[] triggerData
    );
    event AddOrRemoveCollateral(
        bytes32 indexed key,
        bool isPlus,
        uint256 nativeAmount,
        uint256 amountInUSD,
        uint256 reserveAmount,
        uint256 collateral,
        uint256 size
    );
    event AddPosition(bytes32 indexed key, bool confirmDelayStatus, uint256 collateral, uint256 size);
    event AddTrailingStop(bytes32 key, uint256[] data);
    event UpdateTrailingStop(bytes32 key, uint256 stpPrice);
    event UpdateOrder(bytes32 key, uint256 positionType, OrderStatus orderStatus);
    event ConfirmDelayTransactionExecuted(
        bytes32 indexed key,
        bool confirmDelayStatus,
        uint256 collateral,
        uint256 size,
        uint256 feeUsd
    );
    event PositionExecuted(
        bytes32 key,
        address indexed account,
        address indexToken,
        bool isLong,
        uint256 posId,
        uint256[] prices
    );
    event IncreasePosition(
        bytes32 key,
        address indexed account,
        address indexed indexToken,
        bool isLong,
        uint256 posId,
        uint256[7] posData
    );
    event ClosePosition(
        bytes32 key, 
        int256 realisedPnl, 
        uint256 markPrice, 
        uint256 feeUsd, 
        uint256[2] posData
    );
    event DecreasePosition(
        bytes32 key,
        address indexed account,
        address indexed indexToken,
        bool isLong,
        uint256 posId,
        int256 realisedPnl,
        uint256[7] posData
    );
    event LiquidatePosition(bytes32 key, int256 realisedPnl, uint256 markPrice, uint256 feeUsd);
    event DecreasePoolAmount(address indexed token, bool isLong, uint256 amount);
    event DecreaseReservedAmount(address indexed token, bool isLong, uint256 amount);
    event IncreasePoolAmount(address indexed token, bool isLong, uint256 amount);
    event IncreaseReservedAmount(address indexed token, bool isLong, uint256 amount);
    
    modifier onlyPositionHandler() {
        require(positionHandler != address(0) && msg.sender == positionHandler, "Forbidden");
        _;
    }
    
    //Config functions
    function setRouter(address _router) external onlyOwner {
        require(Address.isContract(_router), "Invalid router");
        router = _router;
        emit SetRouter(_router);
    }

    function setPositionHandler(address _positionHandler) external onlyOwner {
        require(Address.isContract(_positionHandler), "Invalid positionHandler");
        positionHandler = _positionHandler;
        emit SetPositionHandler(_positionHandler);
    }

    function setSettingsManager(address _setttingsManager) external onlyOwner {
        require(Address.isContract(_setttingsManager), "Invalid settingsManager");
        settingsManager = _setttingsManager;
        emit SetSettingsManager(_setttingsManager);
    }
    //End config functions

    function openNewPosition(
        bytes32 _key,
        bool _isLong, 
        uint256 _posId,
        uint256 _collateralIndex,
        address[] memory _path,
        uint256[] memory _params,
        bytes memory _data
    ) external nonReentrant onlyPositionHandler {
        _validateSettingsManager();
        Position memory position;
        OrderInfo memory order;

        //Scope to avoid stack too deep error
        {
            (positions[_key], orders[_key]) = abi.decode(_data, ((Position), (OrderInfo)));
            position = positions[_key];
            order = orders[_key];
        }

        if (finalPaths[_key].collateralToken == address(0)) {
            finalPaths[_key].collateralToken = _path[_collateralIndex];
            finalPaths[_key].indexToken = _path[0];
        }

        emit NewOrder(
            _key, 
            position.owner, 
            _isLong, 
            _posId, 
            order.positionType, 
            order.status, 
            _path,
            _collateralIndex,
            _params
        );

        lastPositionIndex[position.owner] += 1;
    }

    function unpackAndStorage(bytes32 _key, bytes memory _data, DataType _dataType) external nonReentrant onlyPositionHandler {
        if (_dataType == DataType.POSITION) {
            positions[_key] = abi.decode(_data, (Position));
        } else if (_dataType == DataType.ORDER) {
            orders[_key] = abi.decode(_data, (OrderInfo));
        } else {
            revert("Invalid data type");
        }
    }

    function deletePosition(bytes32 _key) external override nonReentrant onlyPositionHandler {
        _deletePositions(_key, false);
    }

    function deleteOrder(bytes32 _key) external override nonReentrant onlyPositionHandler {
        delete orders[_key];
    }

    function deletePositions(bytes32 _key) external override nonReentrant onlyPositionHandler {
        _deletePositions(_key, true);
    } 

    function _deletePositions(bytes32 _key, bool _isDeleteOrder) internal {
        if (_isDeleteOrder) {
            delete orders[_key];
        }

        delete positions[_key];
    }

    function increaseReservedAmount(address _token, bool _isLong, uint256 _amount) external override nonReentrant onlyPositionHandler {
        reservedAmounts[_token][_isLong] += _amount;
        emit IncreaseReservedAmount(_token, _isLong, reservedAmounts[_token][_isLong]);
    }

    function decreaseReservedAmount(address _token, bool _isLong, uint256 _amount) external override nonReentrant onlyPositionHandler {
        require(reservedAmounts[_token][_isLong] >= _amount, "Vault: reservedAmounts exceeded");
        reservedAmounts[_token][_isLong] -= _amount;
        emit DecreaseReservedAmount(_token, _isLong, reservedAmounts[_token][_isLong]);
    }

    function increasePoolAmount(address _indexToken, bool _isLong, uint256 _amount) external override nonReentrant onlyPositionHandler {
        poolAmounts[_indexToken][_isLong] += _amount;
        emit IncreasePoolAmount(_indexToken, _isLong, poolAmounts[_indexToken][_isLong]);
    }

    function decreasePoolAmount(address _indexToken, bool _isLong, uint256 _amount) external override nonReentrant onlyPositionHandler {
        require(poolAmounts[_indexToken][_isLong] >= _amount, "Vault: poolAmount exceeded");
        poolAmounts[_indexToken][_isLong] -= _amount;
        emit DecreasePoolAmount(_indexToken, _isLong, poolAmounts[_indexToken][_isLong]);
    }

    //Emit event functions
    function emitAddPositionEvent(
        bytes32 key, 
        bool confirmDelayStatus, 
        uint256 collateral, 
        uint256 size
    ) external nonReentrant onlyPositionHandler {
        emit AddPosition(key, confirmDelayStatus, collateral, size);
    }

    function emitAddOrRemoveCollateralEvent(
        bytes32 _key,
        bool _isPlus,
        uint256 _amount,
        uint256 _amountInUSD,
        uint256 _reserveAmount,
        uint256 _collateral,
        uint256 _size
    ) external nonReentrant onlyPositionHandler {
        emit AddOrRemoveCollateral(
            _key,
            _isPlus,
            _amount,
            _amountInUSD,
            _reserveAmount,
            _collateral,
            _size
        );
    }

    function emitAddTrailingStopEvent(bytes32 _key, uint256[] memory _data) external nonReentrant onlyPositionHandler {
        emit AddTrailingStop(_key, _data);
    }

    function emitUpdateTrailingStopEvent(bytes32 _key, uint256 _stpPrice) external nonReentrant onlyPositionHandler {
        emit UpdateTrailingStop(_key, _stpPrice);
    }

    function emitUpdateOrderEvent(bytes32 _key, uint256 _positionType, OrderStatus _orderStatus) external nonReentrant onlyPositionHandler {
        emit UpdateOrder(_key, _positionType, _orderStatus);
    }

    function emitConfirmDelayTransactionEvent(
        bytes32 _key,
        bool _confirmDelayStatus,
        uint256 _collateral,
        uint256 _size,
        uint256 _feeUsd
    ) external nonReentrant onlyPositionHandler {
        emit ConfirmDelayTransactionExecuted(_key, _confirmDelayStatus, _collateral, _size, _feeUsd);
    }

    function emitPositionExecutedEvent(
        bytes32 _key,
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256[] memory _prices
    ) external nonReentrant onlyPositionHandler {
        emit PositionExecuted(
            _key,
            _account,
            _indexToken,
            _isLong,
            _posId,
            _prices
        );
    }

    function emitIncreasePositionEvent(
        bytes32 _key,
        uint256 _indexPrice,
        uint256 _fee,
        uint256 _collateralDelta,
        uint256 _sizeDelta
    ) external nonReentrant onlyPositionHandler {
        Position memory position = positions[_key];
        PositionBond memory bond = IRouter(router).getBond(_key);

        emit IncreasePosition(
            _key,
            position.owner,
            bond.indexToken,
            bond.isLong,
            bond.posId,
            [
                _collateralDelta,
                _sizeDelta,
                position.reserveAmount,
                position.entryFundingRate,
                position.averagePrice,
                _indexPrice,
                _fee
            ]
        );
    }

    function emitDecreasePositionEvent(
        bytes32 _key,
        uint256 _indexPrice,
        uint256 _fee,
        uint256 _collateralDelta,
        uint256 _sizeDelta
    ) external override onlyPositionHandler {
        Position memory position = positions[_key];
        PositionBond memory bond = IRouter(router).getBond(_key);
        emit DecreasePosition(
            _key,
            position.owner,
            bond.indexToken,
            bond.isLong,
            bond.posId,
            position.realisedPnl,
            [
                _collateralDelta,
                _sizeDelta,
                position.reserveAmount,
                position.entryFundingRate,
                position.averagePrice,
                _indexPrice,
                _fee
            ]
        );
    }

    function emitClosePositionEvent(
        bytes32 _key,
        uint256 _indexPrice,
        uint256 _collateralDelta,
        uint256 _sizeDelta
    ) external override onlyPositionHandler {
        Position memory position = positions[_key];
        PositionBond memory bond = IRouter(router).getBond(_key);
        _validateSettingsManager();
        uint256 migrateFeeUsd = ISettingsManager(settingsManager).collectMarginFees(
            position.owner,
            bond.indexToken,
            bond.isLong,
            position.size,
            position.size,
            position.entryFundingRate
        );
        delete positions[_key];
        emit ClosePosition(
            _key, 
            position.realisedPnl, 
            _indexPrice, 
            migrateFeeUsd, 
            [
                _collateralDelta, 
                _sizeDelta
            ]
        );
    }

    function emitLiquidatePositionEvent(
        bytes32 _key,
        address _indexToken,
        bool _isLong,
        uint256 _indexPrice
    ) external override onlyPositionHandler {
        Position memory position = positions[_key];
        _validateSettingsManager();
        uint256 migrateFeeUsd = ISettingsManager(settingsManager).collectMarginFees(
            position.owner,
            _indexToken,
            _isLong,
            position.size,
            position.size,
            position.entryFundingRate
        );
        delete positions[_key];
        emit LiquidatePosition(_key, position.realisedPnl, _indexPrice, migrateFeeUsd);
    }
    //End emit event functions

    //View functions
    function getPositions(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId
    ) external view override returns (Position memory, OrderInfo memory) {
        bytes32 key = _getPositionKey(_account, _indexToken, _isLong, _posId);
        Position memory position = positions[key];
        OrderInfo memory order = orders[key];
        return (position, order);
    }

    function getPositions(bytes32 _key) external view override returns (Position memory, OrderInfo memory) {
        return (positions[_key], orders[_key]);
    }

    function getPosition(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId
    ) external view override returns (Position memory) {
        return positions[_getPositionKey(_account, _indexToken, _isLong, _posId)];
    }

    function getPosition(bytes32 _key) external override view returns (Position memory) {
        return positions[_key];
    }

    function getOrder(bytes32 _key) external override view returns (OrderInfo memory) {
        return orders[_key];
    }

    function getPositionFee(bytes32 _key) external override view returns (uint256) {
        return positions[_key].totalFee;
    }

    function getPositionSize(bytes32 _key) external override view returns (uint256) {
        return positions[_key].size;
    } 

    function getPositionCollateralToken(bytes32 _key) external override view returns (address) {
        return finalPaths[_key].collateralToken;
    }

    function getPositionIndexToken(bytes32 _key) external override view returns (address) {
        return finalPaths[_key].indexToken;
    }

    function getPositionFinalPath(bytes32 _key) external override view returns (address[] memory) {
        address[] memory finalPath = new address[](2);
        finalPath[0] = finalPaths[_key].indexToken;
        finalPath[1] = finalPaths[_key].collateralToken;
        return finalPath;
    }

    function getPositionOwner(bytes32 _key) external override view returns (address) {
        return positions[_key].owner;
    }

    function _validateSettingsManager() internal view {
        require(settingsManager != address(0), "Settings manager not initialzied");
    }
}