// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../access/BaseExecutor.sol";
import "./interfaces/IPositionKeeper.sol";
import "./interfaces/IPositionHandler.sol";
import "./interfaces/IPriceManager.sol";
import "./interfaces/ISettingsManager.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IVaultUtils.sol";
import "./interfaces/ITriggerOrderManager.sol";
import "./interfaces/IRouter.sol";

import {PositionConstants} from "../constants/PositionConstants.sol";
import {Position, OrderInfo, OrderStatus, OrderType, DataType} from "../constants/Structs.sol";

contract PositionHandler is PositionConstants, IPositionHandler, BaseExecutor {
    mapping(bytes32 => bool) private processing;

    IPositionKeeper public positionKeeper;
    IPriceManager public priceManager;
    ISettingsManager public settingsManager;
    ITriggerOrderManager public triggerOrderManager;
    IVault public vault;
    IVaultUtils public vaultUtils;
    bool public isInitialized;
    address public router;

    event Initialized(
        IPriceManager priceManager,
        ISettingsManager settingsManager,
        ITriggerOrderManager triggerOrderManager,
        IVault vault,
        IVaultUtils vaultUtils
    );
    event SetRouter(address router);
    event SetPositionKeeper(address positionKeeper);
    event SyncPriceOutdated(bytes32 key, uint256 txType, address[] path);

    modifier onlyRouter() {
        require(msg.sender == router, "FBD");
        _;
    }

    modifier inProcess(bytes32 key) {
        require(!processing[key], "InP"); //In processing
        processing[key] = true;
        _;
        processing[key] = false;
    }

    //Config functions
    function setRouter(address _router) external onlyOwner {
        require(Address.isContract(_router), "IVLCA"); //Invalid contract address
        router = _router;
        emit SetRouter(_router);
    }

    function setPositionKeeper(address _positionKeeper) external onlyOwner {
        require(Address.isContract(_positionKeeper), "IVLC/PK"); //Invalid contract positionKeeper
        positionKeeper = IPositionKeeper(_positionKeeper);
        emit SetPositionKeeper(_positionKeeper);
    }

    function initialize(
        IPriceManager _priceManager,
        ISettingsManager _settingsManager,
        ITriggerOrderManager _triggerOrderManager,
        IVault _vault,
        IVaultUtils _vaultUtils
    ) external onlyOwner {
        require(!isInitialized, "AI"); //Already initialized
        require(Address.isContract(address(_priceManager)), "IVLC/PM"); //Invalid contract priceManager
        require(Address.isContract(address(_settingsManager)), "IVLC/SM"); //Invalid contract settingsManager
        require(Address.isContract(address(_triggerOrderManager)), "IVLC/TOM"); //Invalid contract triggerOrderManager
        require(Address.isContract(address(_vault)), "IVLC/V"); //Invalid contract vault
        require(Address.isContract(address(_vaultUtils)), "IVLC/VU"); //Invalid contract vaultUtils
        priceManager = _priceManager;
        settingsManager = _settingsManager;
        triggerOrderManager = _triggerOrderManager;
        vault = _vault;
        vaultUtils = _vaultUtils;
        isInitialized = true;
        emit Initialized(
            _priceManager,
            _settingsManager,
            _triggerOrderManager,
            _vault,
            _vaultUtils
        );
    }
    //End config functions

    function openNewPosition(
        bytes32 _key,
        bool _isLong, 
        uint256 _posId,
        uint256 _collateralIndex,
        bytes memory _data,
        uint256[] memory _params,
        uint256[] memory _prices, 
        address[] memory _path,
        bool _isFastExecute,
        bool _isNewPosition
    ) external override onlyRouter inProcess(_key) {
        require(_collateralIndex > 0 && _collateralIndex < _path.length, "IVLCTI"); //Invalid collateral index
        (Position memory position, OrderInfo memory order) = abi.decode(_data, ((Position), (OrderInfo)));
        vaultUtils.validatePositionData(
            _isLong, 
            _getFirstPath(_path), 
            _getOrderType(order.positionType), 
            _getFirstParams(_prices), 
            _params, 
            true
        );
        
        if (order.positionType == POSITION_MARKET && _isFastExecute) {
            _increaseMarketPosition(
                _key,
                _isLong,
                _collateralIndex,
                _path,
                _prices, 
                position,
                order
            );
            vault.decreaseBond(_key, position.owner, CREATE_POSITION_MARKET);
        }

        if (_isNewPosition) {
            positionKeeper.openNewPosition(
                _key,
                _isLong,
                _posId,
                _collateralIndex,
                _path,
                _params, 
                abi.encode(position, order)
            );
        } else {
            positionKeeper.unpackAndStorage(_key, abi.encode(position), DataType.POSITION);
        }
    }

    function _increaseMarketPosition(
        bytes32 _key,
        bool _isLong,
        uint256 _collateralIndex,
        address[] memory _path,
        uint256[] memory _prices, 
        Position memory _position,
        OrderInfo memory _order
    ) internal {
        require(_order.pendingCollateral > 0 && _order.pendingSize > 0, "IVLOPC/S"); //Invalid order pending collateral/size
        uint256 collateralDecimals = priceManager.getTokenDecimals(_path[_collateralIndex]);
        uint256 collateralPrice = _getLastParams(_prices);
        uint256 pendingCollateral = _fromTokenToUSD(_order.pendingCollateral, collateralPrice, collateralDecimals);
        uint256 pendingSize = _fromTokenToUSD(_order.pendingSize, collateralPrice, collateralDecimals);
        _increasePosition(
            _key,
            pendingCollateral,
            pendingSize,
            _isLong,
            _path,
            _prices,
            _position
        );
        _order.pendingCollateral = 0;
        _order.pendingSize = 0;
        _order.collateralToken = address(0);
    }

    function modifyPosition(
        address _account,
        bool _isLong,
        uint256 _posId,
        uint256 _txType, 
        bytes memory _data,
        address[] memory _path,
        uint256[] memory _prices
    ) external onlyRouter inProcess(_getPositionKey(_account, _getFirstPath(_path), _isLong, _posId)) {
        if (_txType != CANCEL_PENDING_ORDER) {
            require(_path.length == _prices.length && _path.length > 0, "IVLARL"); //Invalid array length
        }
        
        bytes32 key = _getPositionKey(_account, _getFirstPath(_path), _isLong, _posId);
        require(_account == positionKeeper.getPositionOwner(key), "IVLPO"); //Invalid positionOwner
        bool isDelayPosition = false;
        uint256 delayPositionTxType;

        if (_txType == ADD_COLLATERAL || _txType == REMOVE_COLLATERAL) {
            (uint256 amountIn, Position memory position) = abi.decode(_data, ((uint256), (Position)));
            _addOrRemoveCollateral(
                key, 
                _isLong,
                _txType, 
                amountIn, 
                _path, 
                _prices, 
                position
            );
        } else if (_txType == ADD_TRAILING_STOP) {
            (uint256[] memory params, OrderInfo memory order) = abi.decode(_data, ((uint256[]), (OrderInfo)));
            _addTrailingStop(key, _isLong, params, order, _getFirstParams(_prices));
        } else if (_txType == UPDATE_TRAILING_STOP) {
            (OrderInfo memory order) = abi.decode(_data, ((OrderInfo)));
            _updateTrailingStop(key, _isLong, _getFirstParams(_prices), order);
        } else if (_txType == CANCEL_PENDING_ORDER) {
            OrderInfo memory order = abi.decode(_data, ((OrderInfo)));
            _cancelPendingOrder(_account, key, order);
        } else if (_txType == CLOSE_POSITION) {
            (uint256 sizeDelta, Position memory position) = abi.decode(_data, ((uint256), (Position)));
            require(sizeDelta > 0 && sizeDelta <= position.size, "IVLPSD"); //Invalid position size delta
            _decreasePosition(
                _getFirstPath(_path),
                sizeDelta,
                _isLong,
                _posId,
                _prices,
                position
            );
        } else if (_txType == TRIGGER_POSITION) {
            (Position memory position, OrderInfo memory order) = abi.decode(_data, ((Position), (OrderInfo)));
            isDelayPosition = position.size == 0;
            delayPositionTxType = isDelayPosition ? _getTxTypeFromPositionType(order.positionType) : 0;
            _triggerPosition(
                key,
                _isLong,
                _posId,
                _path,
                _prices,
                position,
                order
            );
        } else if (_txType == ADD_POSITION) {
            (
                uint256 pendingCollateral, 
                uint256 pendingSize, 
                Position memory position
            ) = abi.decode(_data, ((uint256), (uint256), (Position)));
            _confirmDelayTransaction(
                _isLong,
                _posId,
                pendingCollateral,
                pendingSize,
                _path,
                _prices,
                position
            );
        } else if (_txType == LIQUIDATE_POSITION) {
            (Position memory position) = abi.decode(_data, (Position));
            _liquidatePosition(
                _isLong,
                _posId,
                _prices,
                _path,
                position
            );
        } else if (_txType == REVERT_EXECUTE) {
            (uint256 originalTxType, Position memory position) = abi.decode(_data, ((uint256), (Position)));

            if (originalTxType == CREATE_POSITION_MARKET && position.size == 0) {
                positionKeeper.deletePosition(key);
            } else if (originalTxType == ADD_TRAILING_STOP || 
                    originalTxType == ADD_COLLATERAL || 
                    _isDelayPosition(originalTxType)) {
                positionKeeper.deleteOrder(key);
            }
        } else {
            revert("IVLTXT"); //Invalid txType
        }

        //Reduce vault bond
        bool isTriggerDelayPosition = _txType == TRIGGER_POSITION && isDelayPosition;

        if (_txType == CREATE_POSITION_MARKET ||
                _txType == ADD_COLLATERAL ||
                _txType == ADD_POSITION ||
                isTriggerDelayPosition) {

            uint256 exactTxType = isTriggerDelayPosition && delayPositionTxType > 0 ? delayPositionTxType : _txType;
            vault.decreaseBond(key, _account, exactTxType);
        }
    }

    /*
    @dev: Set price and execute in batch, temporarily disabled, implement later
    */
    function setPriceAndExecuteInBatch(
        address[] memory _tokens,
        uint256[] memory _prices,
        bytes32[] memory _keys, 
        uint256[] memory _txTypes
    ) external {
        require(_keys.length == _txTypes.length && _keys.length > 0, "IVLARL2"); //Invalid array length
        priceManager.setLatestPrices(_tokens, _prices);
        require(_isExecutor(msg.sender), "FBD/NE"); //Forbidden, not executor 

        for (uint256 i = 0; i < _keys.length; i++) {
            address[] memory path = IRouter(router).getExecutePath(_keys[i], _txTypes[i]);

            if (path.length > 0) {
                (uint256[] memory prices, bool isLastestSync) = priceManager.getLatestSynchronizedPrices(path);

                if (isLastestSync && !processing[_keys[i]]) {
                    try IRouter(router).setPriceAndExecute(_keys[i], _txTypes[i], prices) {}
                    catch (bytes memory err) {
                        IRouter(router).revertExecution(_keys[i], _txTypes[i], path, prices, string(err));
                    }
                } else {
                    emit SyncPriceOutdated(_keys[i], _txTypes[i], path);
                }
            }
        }
    }

    function _addOrRemoveCollateral(
        bytes32 _key,
        bool _isLong,
        uint256 _txType,
        uint256 _amountIn,
        address[] memory _path,
        uint256[] memory _prices,
        Position memory _position
    ) internal {
        uint256 amountInUSD;

        if (_txType == ADD_COLLATERAL) {
            amountInUSD = vaultUtils.validateAddCollateral(
                _position.size, 
                _position.collateral, 
                _amountIn, 
                _getLastPath(_path), 
                _getLastParams(_prices)
            );
            _position.collateral += amountInUSD;
            _position.reserveAmount += amountInUSD;
            positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
            positionKeeper.increasePoolAmount(_getFirstPath(_path), _isLong, amountInUSD);
        } else {
            require(_amountIn <= _position.collateral, "ISFPC"); //Insufficient position collateral
            amountInUSD = _amountIn;
            _position.collateral -= _amountIn;
            vaultUtils.validateRemoveCollateral(
                amountInUSD, 
                _isLong, 
                _getFirstPath(_path), 
                _getFirstParams(_prices), 
                _position
            );
            _position.reserveAmount -= _amountIn;
            _position.lastIncreasedTime = block.timestamp;

            vault.takeAssetOut(
                _position.owner, 
                _position.refer, 
                0,
                _amountIn, 
                positionKeeper.getPositionCollateralToken(_key), 
                _getLastParams(_prices)
            );

            positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
            positionKeeper.decreasePoolAmount(_getFirstPath(_path), _isLong, _amountIn);
        }

        positionKeeper.emitAddOrRemoveCollateralEvent(
            _key, 
            _txType == ADD_COLLATERAL, 
            _amountIn,
            amountInUSD,
            _position.reserveAmount, 
            _position.collateral, 
            _position.size
        );
    }

    function _addTrailingStop(
        bytes32 _key,
        bool _isLong,
        uint256[] memory _params,
        OrderInfo memory _order,
        uint256 _indexPrice
    ) internal {
        require(positionKeeper.getPositionSize(_key) > 0, "IVLPSZ"); //Invalid position size
        vaultUtils.validateTrailingStopInputData(_key, _isLong, _params, _indexPrice);
        _order.pendingCollateral = _getFirstParams(_params);
        _order.pendingSize = _params[1];
        _order.status = OrderStatus.PENDING;
        _order.positionType = POSITION_TRAILING_STOP;
        _order.stepType = _params[2];
        _order.stpPrice = _params[3];
        _order.stepAmount = _params[4];
        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
        positionKeeper.emitAddTrailingStopEvent(_key, _params);
    }

    function _cancelPendingOrder(
        address _account,
        bytes32 _key,
        OrderInfo memory _order
    ) internal {
        require(_order.status == OrderStatus.PENDING, "IVLOS/P"); //Invalid _order status, must be pending
        require(_order.positionType != POSITION_MARKET, "NACMO"); //Not allowing cancel market order
        bool isTrailingStop = _order.positionType == POSITION_TRAILING_STOP;

        if (isTrailingStop) {
            require(_order.pendingCollateral > 0, "IVLOPDC");
        } else {
            require(_order.pendingCollateral > 0  && _order.collateralToken != address(0), "IVLOPDC/T"); //Invalid order pending collateral or token
        }
        
        _order.pendingCollateral = 0;
        _order.pendingSize = 0;
        _order.lmtPrice = 0;
        _order.stpPrice = 0;
        _order.collateralToken = address(0);

        if (isTrailingStop) {
            _order.status = OrderStatus.FILLED;
            _order.positionType = POSITION_MARKET;
        } else {
            _order.status = OrderStatus.CANCELED;
        }
        
        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
        positionKeeper.emitUpdateOrderEvent(_key, _order.positionType, _order.status);

        if (!isTrailingStop) {
            vault.takeAssetBack(
                _account, 
                _key, 
                _getTxTypeFromPositionType(_order.positionType)
            );
        }
    }

    function _triggerPosition(
        bytes32 _key,
        bool _isLong,
        uint256 _posId,
        address[] memory _path, 
        uint256[] memory _prices, 
        Position memory _position, 
        OrderInfo memory _order
    ) internal {
        settingsManager.updateCumulativeFundingRate(_getFirstPath(_path), _isLong);
        uint8 statusFlag = vaultUtils.validateTrigger(_isLong, _getFirstParams(_prices), _order);
        (bool hitTrigger, uint256 triggerAmountPercent) = triggerOrderManager.executeTriggerOrders(
            _position.owner,
            _getFirstPath(_path),
            _isLong,
            _posId,
            _getFirstParams(_prices)
        );
        require(statusFlag == ORDER_FILLED || hitTrigger, "TGNRD");  //Trigger not ready

        //When TriggerOrder from TriggerOrderManager reached price condition
        if (hitTrigger) {
            _decreasePosition(
                _getFirstPath(_path),
                (_position.size * (triggerAmountPercent)) / BASIS_POINTS_DIVISOR,
                _isLong,
                _posId,
                _prices,
                _position
            );
        }

        //When limit/stopLimit/stopMarket order reached price condition 
        if (statusFlag == ORDER_FILLED) {
            if (_order.positionType == POSITION_LIMIT || _order.positionType == POSITION_STOP_MARKET) {
                uint256 collateralDecimals = priceManager.getTokenDecimals(_order.collateralToken);
                uint256 collateralPrice = _getLastParams(_prices);
                _increasePosition(
                    _key,
                    _fromTokenToUSD(_order.pendingCollateral, collateralPrice, collateralDecimals),
                    _fromTokenToUSD(_order.pendingSize, collateralPrice, collateralDecimals),
                    _isLong,
                    _path,
                    _prices, 
                    _position
                );
                _order.pendingCollateral = 0;
                _order.pendingSize = 0;
                _order.status = OrderStatus.FILLED;
                _order.collateralToken = address(0);
            } else if (_order.positionType == POSITION_STOP_LIMIT) {
                _order.positionType = POSITION_LIMIT;
            } else if (_order.positionType == POSITION_TRAILING_STOP) {
                //Double check position size and collateral if hitTriggered
                if (_position.size > 0 && _position.collateral > 0) {
                    _decreasePosition(_getFirstPath(_path), _order.pendingSize, _isLong, _posId, _prices, _position);
                    _order.positionType = POSITION_MARKET;
                    _order.pendingCollateral = 0;
                    _order.pendingSize = 0;
                    _order.status = OrderStatus.FILLED;
                    _order.collateralToken = address(0);
                }
            }
        }

        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
        positionKeeper.emitUpdateOrderEvent(_key, _order.positionType, _order.status);
    }

    function _confirmDelayTransaction(
        bool _isLong,
        uint256 _posId,
        uint256 _pendingCollateral,
        uint256 _pendingSize,
        address[] memory _path,
        uint256[] memory _prices,
        Position memory _position
    ) internal {
        bytes32 key = _getPositionKey(_position.owner, _getFirstPath(_path), _isLong, _posId);
        vaultUtils.validateConfirmDelay(_position.owner, _getFirstPath(_path), _isLong, _posId, true);
        require(vault.getBondAmount(key, ADD_POSITION) >= 0, "ISFBA"); //Insufficient bond amount

        uint256 fee = settingsManager.collectMarginFees(
            _position.owner,
            _getFirstPath(_path),
            _isLong,
            _pendingSize,
            _position.size,
            _position.entryFundingRate
        );

        uint256 pendingCollateralInUSD;
        uint256 pendingSizeInUSD;
      
        //Scope to avoid stack too deep error
        {
            uint256 collateralDecimals = priceManager.getTokenDecimals(_getLastPath(_path));
            uint256 collateralPrice = _getLastParams(_prices);
            pendingCollateralInUSD = _fromTokenToUSD(_pendingCollateral, collateralPrice, collateralDecimals);
            pendingSizeInUSD = _fromTokenToUSD(_pendingSize, collateralPrice, collateralDecimals);
        }

        _increasePosition(
            key,
            pendingCollateralInUSD + fee,
            pendingSizeInUSD,
            _isLong,
            _path,
            _prices,
            _position
        );
        positionKeeper.emitConfirmDelayTransactionEvent(
            key,
            true,
            _pendingCollateral,
            _pendingSize,
            fee
        );
    }

    function _liquidatePosition(
        bool _isLong,
        uint256 _posId,
        uint256[] memory _prices,
        address[] memory _path,
        Position memory _position
    ) internal {
        settingsManager.updateCumulativeFundingRate(_getFirstPath(_path), _isLong);
        bytes32 key = _getPositionKey(_position.owner, _getFirstPath(_path), _isLong, _posId);
        (uint256 liquidationState, uint256 marginFees) = vaultUtils.validateLiquidation(
            _position.owner,
            _getFirstPath(_path),
            _isLong,
            false,
            _getFirstParams(_prices),
            _position
        );
        require(liquidationState != LIQUIDATE_NONE_EXCEED, "NLS");

        if (liquidationState == LIQUIDATE_THRESHOLD_EXCEED) {
            // Max leverage exceeded but there is collateral remaining after deducting losses so decreasePosition instead
            _decreasePosition(_getFirstPath(_path), _position.size, _isLong, _posId, _prices, _position);
            positionKeeper.unpackAndStorage(key, abi.encode(_position), DataType.POSITION);
            return;
        }
        marginFees += _position.totalFee;
        _accountDeltaAndFeeIntoTotalBalance(
            key,
            true,
            0,
            marginFees,
            address(0),
            _getLastParams(_prices)
        );
        uint256 bounty = marginFees;
        vault.transferBounty(settingsManager.feeManager(), bounty);
        settingsManager.decreaseOpenInterest(_getFirstPath(_path), _position.owner, _isLong, _position.size);
        positionKeeper.decreasePoolAmount(_getFirstPath(_path), _isLong, marginFees);
        positionKeeper.emitLiquidatePositionEvent(
            key, 
            _getFirstPath(_path), 
            _isLong, 
            _getFirstParams(_prices)
        );
        // Pay the fee receive using the pool, we assume that in general the liquidated amount should be sufficient to cover
        // the liquidation fees
    }

    function _updateTrailingStop(
        bytes32 _key,
        bool _isLong,
        uint256 _indexPrice,
        OrderInfo memory _order
    ) internal {
        vaultUtils.validateTrailingStopPrice(_isLong, _key, true, _indexPrice);
        
        if (_isLong) {
            _order.stpPrice = _order.stepType == 0
                ? _indexPrice - _order.stepAmount
                : (_indexPrice * (BASIS_POINTS_DIVISOR - _order.stepAmount)) / BASIS_POINTS_DIVISOR;
        } else {
            _order.stpPrice = _order.stepType == 0
                ? _indexPrice + _order.stepAmount
                : (_indexPrice * (BASIS_POINTS_DIVISOR + _order.stepAmount)) / BASIS_POINTS_DIVISOR;
        }

        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
        positionKeeper.emitUpdateTrailingStopEvent(_key, _order.stpPrice);
    }

    function _decreasePosition(
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _posId,
        uint256[] memory _prices,
        Position memory _position
    ) internal {
        settingsManager.updateCumulativeFundingRate(_indexToken, _isLong);
        settingsManager.decreaseOpenInterest(
            _indexToken,
            _position.owner,
            _isLong,
            _sizeDelta
        );
        positionKeeper.decreaseReservedAmount(_indexToken, _isLong, _sizeDelta);
        bytes32 key;
        uint256[4] memory posData; //[usdOut, fee, collateralDelta, adjustedDelta]
        bool hasProfit;
        bool isParitalDecrease;

        //Scope to avoid stack too deep error
        {
            key = _getPositionKey(_position.owner, _indexToken, _isLong, _posId);
            (posData, hasProfit, isParitalDecrease, _position) = vaultUtils.beforeDecreasePosition(
                _position.owner,
                _indexToken,
                _isLong, 
                _posId,
                _sizeDelta,
                _getFirstParams(_prices),
                true
            );
        }

        //Collect vault fee
        if (posData[3] > 0) {
            _accountDeltaAndFeeIntoTotalBalance(
                key,
                hasProfit,
                posData[3],
                posData[1],
                address(0),
                _getLastParams(_prices)
            );
        }

        positionKeeper.unpackAndStorage(key, abi.encode(_position), DataType.POSITION);

        if (isParitalDecrease) {
            positionKeeper.emitDecreasePositionEvent(
                key,
                _getFirstParams(_prices), 
                posData[1], 
                posData[2],
                _sizeDelta
            );
        } else {
            positionKeeper.emitClosePositionEvent(
                key,
                _getFirstParams(_prices), 
                posData[2],
                _sizeDelta
            );
        }

        if (posData[1] <= posData[0]) {
            if (posData[1] != posData[0]) {
                positionKeeper.decreasePoolAmount(_indexToken, _isLong, posData[0] - posData[1]);
            }
            
            vault.takeAssetOut(
                _position.owner, 
                _position.refer, 
                posData[1], 
                posData[0], 
                positionKeeper.getPositionCollateralToken(key), 
                _getLastParams(_prices)
            );
        } else if (posData[1] != 0) {
            vault.distributeFee(_position.owner, _position.refer, posData[1], _indexToken);
        }
    }

    function _increasePosition(
        bytes32 _key,
        uint256 _amountIn,
        uint256 _sizeDelta,
        bool _isLong,
        address[] memory _path,
        uint256[] memory _prices,
        Position memory _position
    ) internal {
        settingsManager.updateCumulativeFundingRate(_getFirstPath(_path), _isLong);
        address indexToken;
        uint256 indexPrice;

        {
            indexToken = _getFirstPath(_path);
            indexPrice = _getFirstParams(_prices);
        }

        if (_position.size == 0) {
            _position.averagePrice = indexPrice;
        }

        if (_position.size > 0 && _sizeDelta > 0) {
            _position.averagePrice = priceManager.getNextAveragePrice(
                indexToken,
                _position.size,
                _position.averagePrice,
                _isLong,
                _sizeDelta,
                indexPrice
            );
        }
        uint256 fee = settingsManager.collectMarginFees(
            _position.owner,
            indexToken,
            _isLong,
            _sizeDelta,
            _position.size,
            _position.entryFundingRate
        );
        vault.collectVaultFee(_position.refer, _amountIn);

        //Storage open fee and charge later
        _position.totalFee += fee;
        _position.collateral += _amountIn;
        _position.reserveAmount += _amountIn;
        _position.entryFundingRate = settingsManager.cumulativeFundingRates(indexToken, _isLong);
        _position.size += _sizeDelta;
        _position.lastIncreasedTime = block.timestamp;
        _position.lastPrice = indexPrice;
        _accountDeltaAndFeeIntoTotalBalance(
            bytes32(0),
            true, 
            0, 
            fee, 
            _getLastPath(_path),
            _getLastParams(_prices)
        );
        
        settingsManager.validatePosition(_position.owner, indexToken, _isLong, _position.size, _position.collateral);
        vaultUtils.validateLiquidation(_position.owner, indexToken, _isLong, true, indexPrice, _position);
        settingsManager.increaseOpenInterest(indexToken, _position.owner, _isLong, _sizeDelta);
        positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
        positionKeeper.increaseReservedAmount(indexToken, _isLong, _sizeDelta);
        positionKeeper.increasePoolAmount(indexToken, _isLong, _amountIn);
        positionKeeper.emitIncreasePositionEvent(
            _key,
            indexPrice,
            fee, 
            _amountIn, 
            _sizeDelta
        );
    }

    function _accountDeltaAndFeeIntoTotalBalance(
        bytes32 _key,
        bool _hasProfit,
        uint256 _adjustedDelta,
        uint256 _fee,
        address _collateralToken,
        uint256 _collateralPrice
    ) internal {
        vault.accountDeltaAndFeeIntoTotalBalance(
            _hasProfit, 
            _adjustedDelta, 
            _fee, 
            _collateralToken == address(0) && uint256(_key) > 0 ? positionKeeper.getPositionCollateralToken(_key) : _collateralToken,
            _collateralPrice
        );
    }

    function _validateDecreasePosition(
        address _indexToken,
        bool _isLong,
        uint256 _indexPrice,
        Position memory _position
    ) internal view {
        vaultUtils.validateDecreasePosition(_indexToken, _isLong, true, _indexPrice, _position);
    }

    function _calculateMarginFee(
        address _indexToken, 
        bool _isLong, 
        uint256 _sizeDelta, 
        Position memory _position
    ) internal view returns (uint256){
        return settingsManager.collectMarginFees(
            _position.owner,
            _indexToken,
            _isLong,
            _sizeDelta,
            _position.size,
            _position.entryFundingRate
        );
    }

    /*
    @dev: Set the latest lastPrices for fastPriceFeed
    */
    function _setLatestPrices(address _indexToken, address[] memory _collateralPath, uint256[] memory _prices) internal {
        for (uint256 i = 0; i < _prices.length; i++) {
            uint256 price = _prices[i];

            if (price > 0) {
                try priceManager.setLatestPrice(i == 0 ? _indexToken : _collateralPath[i + 1], price){}
                catch {}
            }
        }
    }

    function _fromTokenToUSD(uint256 _tokenAmount, uint256 _price, uint256 _decimals) internal pure returns (uint256) {
        return (_tokenAmount * _price) / (10 ** _decimals);
    }

    function _getOrderType(uint256 _positionType) internal pure returns (OrderType) {
        if (_positionType == POSITION_MARKET) {
            return OrderType.MARKET;
        } else if (_positionType == POSITION_LIMIT) {
            return OrderType.LIMIT;
        } else if (_positionType == POSITION_STOP_MARKET) {
            return OrderType.STOP;
        } else if (_positionType == POSITION_STOP_LIMIT) {
            return OrderType.STOP_LIMIT;
        } else {
            revert("IVLOT"); //Invalid order type
        }
    }

    function _getFirstPath(address[] memory _path) internal pure returns (address) {
        return _path[0];
    }

    function _getLastPath(address[] memory _path) internal pure returns (address) {
        return _path[_path.length - 1];
    }

    function _getFirstParams(uint256[] memory _params) internal pure returns (uint256) {
        return _params[0];
    }

    function _getLastParams(uint256[] memory _params) internal pure returns (uint256) {
        return _params[_params.length - 1];
    }

    //This function is using for re-intialized settings
    function reInitializedForDev(bool _isInitialized) external onlyOwner {
       isInitialized = _isInitialized;
    }
}