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
import "./interfaces/IPositionRouter.sol";

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
    IPositionRouter public positionRouter;

    event Initialized(
        IPriceManager priceManager,
        ISettingsManager settingsManager,
        ITriggerOrderManager triggerOrderManager,
        IVault vault,
        IVaultUtils vaultUtils
    );
    event SetPositionRouter(address positionRouter);
    event SetPositionKeeper(address positionKeeper);
    event SyncPriceOutdated(bytes32 key, uint256 txType, address[] path);

    modifier onlyRouter() {
        require(msg.sender == address(positionRouter), "FBD");
        _;
    }

    modifier inProcess(bytes32 key) {
        require(!processing[key], "InP"); //In processing
        processing[key] = true;
        _;
        processing[key] = false;
    }

    //Config functions
    function setPositionRouter(address _positionRouter) external onlyOwner {
        require(Address.isContract(_positionRouter), "IVLCA"); //Invalid contract address
        positionRouter = IPositionRouter(_positionRouter);
        emit SetPositionRouter(_positionRouter);
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

    function modifyPosition(
        bytes32 _key,
        uint256 _txType, 
        address[] memory _path,
        uint256[] memory _prices,
        bytes memory _data
    ) external onlyRouter inProcess(_key) {
        if (_txType != CANCEL_PENDING_ORDER) {
            require(_path.length == _prices.length && _path.length > 0, "IVLARL"); //Invalid array length
        }

        address account;
        
        bool isDelayPosition = false;
        uint256 delayPositionTxType;

        if (_isOpenPosition(_txType)) {
            account = _openNewPosition(
                _key,
                _path,
                _prices,
                _data
            );
        } else if (_txType == ADD_COLLATERAL || _txType == REMOVE_COLLATERAL) {
            (uint256 amountIn, Position memory position) = abi.decode(_data, ((uint256), (Position)));
            account = position.owner;
            _addOrRemoveCollateral(
                _key, 
                _txType, 
                amountIn, 
                _path, 
                _prices, 
                position
            );
        } else if (_txType == ADD_TRAILING_STOP) {
            bool isLong;
            uint256[] memory params;
            OrderInfo memory order;

            {
                (account, isLong, params, order) = abi.decode(_data, ((address), (bool), (uint256[]), (OrderInfo)));
                _addTrailingStop(_key, isLong, params, order, _getFirstParams(_prices));
            }
        } else if (_txType == UPDATE_TRAILING_STOP) {
            bool isLong;
            OrderInfo memory order;

            {
                (account, isLong, order) = abi.decode(_data, ((address), (bool), (OrderInfo)));
                _updateTrailingStop(_key, isLong, _getFirstParams(_prices), order);
            }
        } else if (_txType == CANCEL_PENDING_ORDER) {
            OrderInfo memory order;
            
            {
                (account, order) = abi.decode(_data, ((address), (OrderInfo)));
                _cancelPendingOrder(_key, order);
            } 
        } else if (_txType == CLOSE_POSITION) {
            (uint256 sizeDelta, Position memory position) = abi.decode(_data, ((uint256), (Position)));
            require(sizeDelta > 0 && sizeDelta <= position.size, "IVLPSD"); //Invalid position size delta
            account = position.owner;
            _decreasePosition(
                _key,
                sizeDelta,
                _getLastPath(_path),
                _getFirstParams(_prices),
                _getLastParams(_prices),
                position
            );
        } else if (_txType == TRIGGER_POSITION) {
            (Position memory position, OrderInfo memory order) = abi.decode(_data, ((Position), (OrderInfo)));
            isDelayPosition = position.size == 0;
            delayPositionTxType = isDelayPosition ? _getTxTypeFromPositionType(order.positionType) : 0;
            account = position.owner;
            _triggerPosition(
                _key,
                _getLastPath(_path),
                _getFirstParams(_prices),
                _getLastParams(_prices),
                position,
                order
            );
            account = position.owner;
        } else if (_txType == ADD_POSITION) {
            (
                uint256 pendingCollateral, 
                uint256 pendingSize, 
                Position memory position
            ) = abi.decode(_data, ((uint256), (uint256), (Position)));
            account = position.owner;
            _confirmDelayTransaction(
                _key,
                _getLastPath(_path),
                pendingCollateral,
                pendingSize,
                _getFirstParams(_prices),
                _getLastParams(_prices),
                position
            );
        } else if (_txType == LIQUIDATE_POSITION) {
            (Position memory position) = abi.decode(_data, (Position));
            account = position.owner;
            _liquidatePosition(
                _key,
                _getLastPath(_path),
                _getFirstParams(_prices),
                _getLastParams(_prices),
                position
            );
        } else if (_txType == REVERT_EXECUTE) {
            (uint256 originalTxType, Position memory position) = abi.decode(_data, ((uint256), (Position)));
            account = position.owner;

            if (originalTxType == CREATE_POSITION_MARKET && position.size == 0) {
                positionKeeper.deletePositions(_key);
            } else if (originalTxType == ADD_TRAILING_STOP || 
                    originalTxType == ADD_COLLATERAL || 
                    _isDelayPosition(originalTxType)) {
                positionKeeper.deleteOrder(_key);
            }
        } else {
            revert("IVLTXT"); //Invalid txType
        }

        //Reduce vault bond
        bool isTriggerDelayPosition = _txType == TRIGGER_POSITION && isDelayPosition;

        if (_txType == ADD_COLLATERAL ||  _txType == ADD_POSITION || isTriggerDelayPosition) {
            uint256 exactTxType = isTriggerDelayPosition && delayPositionTxType > 0 ? delayPositionTxType : _txType;
            vault.decreaseBond(_key, account, exactTxType);
        }
    }

    function _openNewPosition(
        bytes32 _key,
        address[] memory _path,
        uint256[] memory _prices, 
        bytes memory _data
    ) internal returns (address) {
        bool isFastExecute;
        bool isNewPosition;
        uint256[] memory params;
        Position memory position;
        OrderInfo memory order;
        (isFastExecute, isNewPosition, params, position, order) = abi.decode(_data, ((bool), (bool), (uint256[]), (Position), (OrderInfo)));
        vaultUtils.validatePositionData(
            position.isLong, 
            _getFirstPath(_path), 
            _getOrderType(order.positionType), 
            _getFirstParams(_prices), 
            params, 
            true
        );
        
        if (order.positionType == POSITION_MARKET && isFastExecute) {
            _increaseMarketPosition(
                _key,
                _path,
                _prices, 
                position,
                order
            );
            vault.decreaseBond(_key, position.owner, CREATE_POSITION_MARKET);
        }

        if (isNewPosition) {
            positionKeeper.openNewPosition(
                _key,
                position.isLong,
                position.posId,
                _path,
                params, 
                abi.encode(position, order)
            );
        } else {
            positionKeeper.unpackAndStorage(_key, abi.encode(position), DataType.POSITION);
        }

        return position.owner;
    }

    function _increaseMarketPosition(
        bytes32 _key,
        address[] memory _path,
        uint256[] memory _prices, 
        Position memory _position,
        OrderInfo memory _order
    ) internal {
        require(_order.pendingCollateral > 0 && _order.pendingSize > 0, "IVLPC"); //Invalid pendingCollateral
        uint256 collateralDecimals = priceManager.getTokenDecimals(_getLastPath(_path));
        require(collateralDecimals > 0, "IVLD"); //Invalid decimals
        uint256 pendingCollateral = _order.pendingCollateral;
        uint256 pendingSize = _order.pendingSize;
        _order.pendingCollateral = 0;
        _order.pendingSize = 0;
        _order.collateralToken = address(0);
        _order.status = OrderStatus.FILLED;
        uint256 collateralPrice = _getLastParams(_prices);
        pendingCollateral = _fromTokenToUSD(pendingCollateral, collateralPrice, collateralDecimals);
        pendingSize = _fromTokenToUSD(pendingSize, collateralPrice, collateralDecimals);
        require(pendingCollateral > 0 && pendingSize > 0, "IVLPC"); //Invalid pendingCollateral
        _increasePosition(
            _key,
            pendingCollateral,
            pendingSize,
            _getLastPath(_path),
            _getFirstParams(_prices),
            _position
        );
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
        require(_keys.length == _txTypes.length && _keys.length > 0, "IVLARL"); //Invalid array length
        priceManager.setLatestPrices(_tokens, _prices);
        _validateExecutor(msg.sender);

        for (uint256 i = 0; i < _keys.length; i++) {
            address[] memory path = IPositionRouter(positionRouter).getExecutePath(_keys[i], _txTypes[i]);

            if (path.length > 0) {
                (uint256[] memory prices, bool isLastestSync) = priceManager.getLatestSynchronizedPrices(path);

                if (isLastestSync && !processing[_keys[i]]) {
                    try IPositionRouter(positionRouter).execute(_keys[i], _txTypes[i], prices) {}
                    catch (bytes memory err) {
                        IPositionRouter(positionRouter).revertExecution(_keys[i], _txTypes[i], path, prices, string(err));
                    }
                } else {
                    emit SyncPriceOutdated(_keys[i], _txTypes[i], path);
                }
            }
        }
    }

    function forceClosePosition(bytes32 _key, uint256[] memory _prices) external {
        _validateExecutor(msg.sender);
        _validatePositionKeeper();
        _validateVaultUtils();
        _validateRouter();
        Position memory position = positionKeeper.getPosition(_key);
        require(position.owner != address(0), "IVLPO"); //Invalid positionOwner
        address[] memory path = positionKeeper.getPositionFinalPath(_key);
        require(path.length > 0 && path.length == _prices.length, "IVLAL"); //Invalid array length
        (bool hasProfit, uint256 pnl, , ) = vaultUtils.calculatePnl(
            position.size,
            position.size - position.collateral,
            _getFirstParams(_prices),
            true,
            true,
            true,
            false,
            position
        );
        require(
            hasProfit && pnl >= (vault.getTotalUSD() * settingsManager.maxProfitPercent()) / BASIS_POINTS_DIVISOR,
            "Not allowed"
        );

        _decreasePosition(
            _key,
            position.size,
            _getLastPath(path),
            _getFirstParams(_prices),
            _getLastParams(_prices),
            position
        );
    }

    function _addOrRemoveCollateral(
        bytes32 _key,
        uint256 _txType,
        uint256 _amountIn,
        address[] memory _path,
        uint256[] memory _prices,
        Position memory _position
    ) internal {
        uint256 amountInUSD;

        (amountInUSD, _position) = vaultUtils.validateAddOrRemoveCollateral(
            _amountIn,
            _txType == ADD_COLLATERAL ? true : false,
            _getLastPath(_path), //collateralToken
            _getFirstParams(_prices), //indexPrice
            _getLastParams(_prices), //collateralPrice
            _position
        );

        positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);

        if (_txType == ADD_COLLATERAL) {
            vault.increasePoolAmount(_getLastPath(_path), amountInUSD);
        } else {
            vault.takeAssetOut(
                _key,
                _position.owner, 
                0, //Zero fee for removeCollateral
                _amountIn, 
                _getLastPath(_path), 
                _getLastParams(_prices)
            );

            vault.decreasePoolAmount(_getLastPath(_path), _amountIn);
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
                positionKeeper.getPositionOwner(_key), 
                _key, 
                _getTxTypeFromPositionType(_order.positionType)
            );
        }
    }

    function _triggerPosition(
        bytes32 _key,
        address _collateralToken, 
        uint256 _indexPrice,
        uint256 _collateralPrice,
        Position memory _position, 
        OrderInfo memory _order
    ) internal {
        settingsManager.updateFunding(_position.indexToken, _collateralToken);
        uint8 statusFlag = vaultUtils.validateTrigger(_position.isLong, _indexPrice, _order);
        (bool hitTrigger, uint256 triggerAmountPercent) = triggerOrderManager.executeTriggerOrders(
            _position.owner,
            _position.indexToken,
            _position.isLong,
            _position.posId,
            _indexPrice
        );
        require(statusFlag == ORDER_FILLED || hitTrigger, "TGNRD");  //Trigger not ready

        //When TriggerOrder from TriggerOrderManager reached price condition
        if (hitTrigger) {
            _decreasePosition(
                _key,
                (_position.size * (triggerAmountPercent)) / BASIS_POINTS_DIVISOR,
                _collateralToken,
                _indexPrice,
                _collateralPrice,
                _position
            );
        }

        //When limit/stopLimit/stopMarket order reached price condition 
        if (statusFlag == ORDER_FILLED) {
            if (_order.positionType == POSITION_LIMIT || _order.positionType == POSITION_STOP_MARKET) {
                uint256 collateralDecimals = priceManager.getTokenDecimals(_order.collateralToken);
                _increasePosition(
                    _key,
                    _fromTokenToUSD(_order.pendingCollateral, _collateralPrice, collateralDecimals),
                    _fromTokenToUSD(_order.pendingSize, _collateralPrice, collateralDecimals),
                    _collateralToken,
                    _indexPrice,
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
                    _decreasePosition(
                        _key,
                        _order.pendingSize, 
                        _collateralToken,
                        _indexPrice,
                        _collateralPrice, 
                        _position
                    );
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
        bytes32 _key,
        address _collateralToken,
        uint256 _pendingCollateral,
        uint256 _pendingSize,
        uint256 _indexPrice,
        uint256 _collateralPrice,
        Position memory _position
    ) internal {
        vaultUtils.validateConfirmDelay(_key, true);
        require(vault.getBondAmount(_key, ADD_POSITION) >= 0, "ISFBA"); //Insufficient bond amount
        uint256 pendingCollateralInUSD;
        uint256 pendingSizeInUSD;
      
        //Scope to avoid stack too deep error
        {
            uint256 collateralDecimals = priceManager.getTokenDecimals(_collateralToken);
            pendingCollateralInUSD = _fromTokenToUSD(_pendingCollateral, _collateralPrice, collateralDecimals);
            pendingSizeInUSD = _fromTokenToUSD(_pendingSize, _collateralPrice, collateralDecimals);
            require(pendingCollateralInUSD > 0 && pendingSizeInUSD > 0, "IVLPC"); //Invalid pending collateral
        }

        _increasePosition(
            _key,
            pendingCollateralInUSD,
            pendingSizeInUSD,
            _collateralToken,
            _indexPrice,
            _position
        );
        positionKeeper.emitConfirmDelayTransactionEvent(
            _key,
            true,
            _pendingCollateral,
            _pendingSize,
            _position.previousFee
        );
    }

    function _liquidatePosition(
        bytes32 _key,
        address _collateralToken,
        uint256 _indexPrice,
        uint256 _collateralPrice,
        Position memory _position
    ) internal {
        settingsManager.updateFunding(_position.indexToken, _collateralToken);
        (uint256 liquidationState, uint256 fee) = vaultUtils.validateLiquidation(
            false,
            true,
            false,
            true,
            _indexPrice,
            _position
        );
        require(liquidationState != LIQUIDATE_NONE_EXCEED, "NLS"); //Not liquidated state
        positionKeeper.updateGlobalShortData(_key, _position.size, _indexPrice, false);

        if (_position.isLong) {
            vault.decreaseGuaranteedAmount(_collateralToken, _position.size - _position.collateral);
        }

        if (liquidationState == LIQUIDATE_THRESHOLD_EXCEED) {
            // Max leverage exceeded but there is collateral remaining after deducting losses so decreasePosition instead
            _decreasePosition(
                _key,
                _position.size, 
                _collateralToken, 
                _indexPrice, 
                _collateralPrice, 
                _position
            );
            positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
            return;
        }

        vault.decreaseReservedAmount(_collateralToken, _position.reserveAmount);
        uint256 liquidationFee = settingsManager.liquidationFeeUsd();

        if (_position.isLong) {
            vault.decreaseGuaranteedAmount(_collateralToken, _position.size - _position.collateral);

            if (fee > liquidationFee) {
                vault.decreasePoolAmount(_collateralToken, fee - liquidationFee);
            }
        } 

        if (!_position.isLong && fee < _position.collateral) {
            uint256 remainingCollateral = _position.collateral - fee;
            vault.increasePoolAmount(_collateralToken, remainingCollateral);
        }

        vault.transferBounty(settingsManager.feeManager(), fee);
        settingsManager.decreaseOpenInterest(_position.indexToken, _position.owner, _position.isLong, _position.size);
        vault.decreasePoolAmount(_collateralToken, liquidationFee);
        positionKeeper.emitLiquidatePositionEvent(_key, _indexPrice, fee);
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
        bytes32 _key,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _indexPrice,
        uint256 _collateralPrice,
        Position memory _position
    ) internal {
        settingsManager.updateFunding(_position.indexToken, _collateralToken);
        settingsManager.decreaseOpenInterest(
            _position.indexToken,
            _position.owner,
            _position.isLong,
            _sizeDelta
        );
        //Decrease reserveDelta
        vault.decreaseReservedAmount(_collateralToken, _position.reserveAmount * _sizeDelta / _position.size);

        uint256 prevCollateral;
        uint256[4] memory posData; //[usdOut, fee, collateralDelta, adjustedDelta]
        bool hasProfit;
        bool isParitalClose = _position.size != _sizeDelta;
        int256 fundingFee;

        //Scope to avoid stack too deep error
        {
            positionKeeper.updateGlobalShortData(_key, _sizeDelta, _indexPrice, false);
            prevCollateral = _position.collateral;
            (hasProfit, fundingFee, posData, _position) = _beforeDecreasePosition(
                _sizeDelta, 
                _indexPrice, 
                _position
            );
        }

        //adjustedDelta > 0
        if (posData[3] > 0) {
            if (hasProfit && !_position.isLong) {
            // Pay out realised profits from the pool amount for short positions
                vault.decreasePoolAmount(_collateralToken, posData[3]);
            } else if (!hasProfit && !_position.isLong) {
            // Transfer realised losses to the pool for short positions
            // realised losses for long positions are not transferred here as
            // increasePoolAmount was already called in increasePosition for longs
                vault.increasePoolAmount(_collateralToken, posData[3]);
            }
        }

        if (_position.isLong) {
            vault.increaseGuaranteedAmount(_collateralToken, isParitalClose ? prevCollateral - _position.collateral : prevCollateral);
            vault.decreaseGuaranteedAmount(_collateralToken, _sizeDelta);

            if (posData[0] > 0) {
                //Decrease pool amount if usdOut > 0 and position is long
                vault.decreasePoolAmount(_collateralToken, posData[0]);
            }
        }

        positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
        positionKeeper.emitDecreasePositionEvent(
            _key,
            _indexPrice, 
            posData[2], //collateralDelta
            _sizeDelta,
            posData[1], //tradingFee
            fundingFee,
            isParitalClose
        );

        if (posData[1] <= posData[0]) {
            //Transfer asset out if fee < usdOut
            vault.takeAssetOut(
                _key,
                _position.owner, 
                posData[1], //fee
                posData[0], //usdOut
                _collateralToken, 
                _collateralPrice
            );
        } else if (posData[1] > 0) {
            //Distribute fee
            vault.distributeFee(_key, _position.owner, posData[1]);
        }
    }

    function _beforeDecreasePosition(
        uint256 _sizeDelta, 
        uint256 _indexPrice, 
        Position memory _position
    ) internal view returns (bool hasProfit, int256 fundingFee, uint256[4] memory posData, Position memory) {
        //posData: [usdOut, tradingFee, collateralDelta, adjustedDelta]
        bytes memory encodedData;
        (hasProfit, fundingFee, encodedData) = vaultUtils.beforeDecreasePosition(
            _sizeDelta,
            _indexPrice,
            _position
        );
        (posData, _position) = abi.decode(encodedData, ((uint256[4]), (Position)));
        return (hasProfit, fundingFee, posData, _position);
    }

    function _increasePosition(
        bytes32 _key,
        uint256 _amountIn,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _indexPrice,
        Position memory _position
    ) internal {
        require(_sizeDelta > 0, "IVLPSD"); //Invalid position sizeDelta
        settingsManager.updateFunding(_position.indexToken, _collateralToken);
        positionKeeper.updateGlobalShortData(_key, _sizeDelta, _indexPrice, true);
        uint256 fee;

        if (_position.size == 0) {
            _position.averagePrice = _indexPrice;
            _position.entryFunding = settingsManager.fundingIndex(_position.indexToken);
            (fee, ) = settingsManager.getFees(
                _sizeDelta,
                0,
                true,
                false,
                false,
                _position
            );
        } else {
            (uint256 newAvgPrice, int256 newEntryFunding) = vaultUtils.reCalculatePosition(
                _sizeDelta, 
                _sizeDelta -_amountIn,
                _indexPrice, 
                _position
            );
            _position.averagePrice = newAvgPrice;
            _position.entryFunding = newEntryFunding;
            (fee, ) = settingsManager.getFees(
                _sizeDelta,
                _position.size - _position.collateral,
                true,
                true,
                false,
                _position
            );
        }

        //Storage fee and charge later
        _position.previousFee += fee;
        _position.collateral += _amountIn;
        _position.reserveAmount += _amountIn;
        _position.size += _sizeDelta;
        _position.lastIncreasedTime = block.timestamp;
        _position.lastPrice = _indexPrice;
        
        settingsManager.validatePosition(
            _position.owner, 
            _position.indexToken, 
            _position.isLong, 
            _position.size, 
            _position.collateral
        );
        vaultUtils.validateLiquidation(true, false, false, false, _indexPrice, _position);
        settingsManager.increaseOpenInterest(_position.indexToken, _position.owner, _position.isLong, _sizeDelta);
        positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
        vault.increaseReservedAmount(_collateralToken, _sizeDelta);

        if (_position.isLong) {
            //Only increase pool amount for long position
            vault.increasePoolAmount(_collateralToken, _amountIn);
            vault.decreasePoolAmount(_collateralToken, uint256(fee));
            vault.increaseGuaranteedAmount(_collateralToken, _sizeDelta + uint256(fee));
            vault.decreaseGuaranteedAmount(_collateralToken, _amountIn);
        } 

        positionKeeper.emitIncreasePositionEvent(
            _key,
            _indexPrice,
            _amountIn, 
            _sizeDelta,
            fee
        );
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
            revert("Invalid orderType");
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

    function _validateExecutor(address _account) internal view {
        require(_isExecutor(_account), "FBD"); //Forbidden, not executor 
    }

    function _validatePositionKeeper() internal view {
        require(Address.isContract(address(positionKeeper)), "IVLCA"); //Invalid contractAddress
    }

    function _validateVaultUtils() internal view {
        require(Address.isContract(address(vaultUtils)), "IVLCA"); //Invalid contractAddress
    }

    function _validateRouter() internal view {
        require(Address.isContract(address(positionRouter)), "IVLCA"); //Invalid contractAddress
    }

    //This function is using for re-intialized settings
    function reInitializedForDev(bool _isInitialized) external onlyOwner {
       isInitialized = _isInitialized;
    }
}