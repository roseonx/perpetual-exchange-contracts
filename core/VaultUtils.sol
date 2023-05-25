// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IPositionKeeper.sol";
import "./interfaces/IPriceManager.sol";
import "./interfaces/ISettingsManager.sol";
import "./interfaces/IVaultUtils.sol";
import "./interfaces/IRouter.sol";

import {Constants} from "../constants/Constants.sol";
import {BasePositionConstants} from "../constants/BasePositionConstants.sol";
import {PositionBond, Position, OrderInfo, PrepareTransaction, OrderStatus} from "../constants/Structs.sol";

contract VaultUtils is IVaultUtils, BasePositionConstants, Constants, Ownable {
    IPositionKeeper public positionKeeper;
    IPriceManager public priceManager;
    ISettingsManager public settingsManager;
    address public router;
    address public positionHandler;

    event SetRouter(address router);
    event SetPositionHandler(address positionHandler);
    event SetPositionKeeper(address positionKeeper);

    constructor(address _priceManager, address _settingsManager) {
        priceManager = IPriceManager(_priceManager);
        settingsManager = ISettingsManager(_settingsManager);
    }

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

    function setPositionKeeper(address _positionKeeper) external onlyOwner {
        require(Address.isContract(_positionKeeper), "PostionKeeper invalid");
        positionKeeper = IPositionKeeper(_positionKeeper);
        emit SetPositionKeeper(_positionKeeper);
    }

    function validateConfirmDelay(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        bool _raise
    ) external view override returns (bool) {
        PrepareTransaction memory transaction = IRouter(router).getTransaction(_getPositionKey(_account, _indexToken, _isLong, _posId));
        bool validateFlag;
        
        // uint256 public constant ADD_POSITION = 7;
        if (transaction.txType == 7) {
            if (block.timestamp >= (transaction.startTime + settingsManager.delayDeltaTime())) {
                validateFlag = true;
            } else {
                validateFlag = false;
            }
        } else {
            validateFlag = false;
        }

        if (_raise) {
            require(validateFlag, "Order is still in delay pending");
        }

        return validateFlag;
    }

    function validateDecreasePosition(
        address _indexToken,
        bool _isLong,
        bool _raise, 
        uint256 _indexPrice,
        Position memory _position
    ) external view override returns (bool) {
        return _validateDecreasePosition(
            _indexToken,
            _isLong,
            _raise, 
            _indexPrice,
            _position
        );
    }

     function _validateDecreasePosition(
        address _indexToken,
        bool _isLong,
        bool _raise, 
        uint256 _indexPrice,
        Position memory _position
    ) internal view returns (bool) {
        bool validateFlag;
        (bool hasProfit, ) = priceManager.getDelta(_indexToken, _position.size, _position.averagePrice, _isLong, _indexPrice);

        if (hasProfit) {
            if (
                _position.lastIncreasedTime > 0 &&
                _position.lastIncreasedTime < block.timestamp - settingsManager.closeDeltaTime()
            ) {
                validateFlag = true;
            } else {
                uint256 price = _indexPrice > 0 ? _indexPrice : priceManager.getLastPrice(_indexToken);

                if (
                    (_isLong &&
                        price * BASIS_POINTS_DIVISOR >=
                        (BASIS_POINTS_DIVISOR + settingsManager.priceMovementPercent()) * _position.lastPrice) ||
                    (!_isLong &&
                        price * BASIS_POINTS_DIVISOR <=
                        (BASIS_POINTS_DIVISOR - settingsManager.priceMovementPercent()) * _position.lastPrice)
                ) {
                    validateFlag = true;
                }
            }
        } else {
            validateFlag = true;
        }

        if (_raise) {
            require(validateFlag, "Not allowed to close the position");
        }

        return validateFlag;
    }

     function validateLiquidation(
        address _account,
        address _indexToken,
        bool _isLong,
        bool _raise, 
        uint256 _indexPrice,
        Position memory _position
    ) external view override returns (uint256, uint256) {
        return _validateLiquidation(
            _account,
            _indexToken,
            _isLong,
            _raise, 
            _indexPrice,
            _position
        );
    }

    function _validateLiquidation(
        address _account,
        address _indexToken,
        bool _isLong,
        bool _raise, 
        uint256 _indexPrice,
        Position memory _position
    ) internal view returns (uint256, uint256) {
        if (_position.averagePrice > 0) {
            (bool hasProfit, uint256 delta) = priceManager.getDelta(
                _indexToken,
                _position.size,
                _position.averagePrice,
                _isLong,
                _indexPrice
            );
            uint256 migrateFeeUsd = settingsManager.collectMarginFees(
                _account,
                _indexToken,
                _isLong,
                _position.size,
                _position.size,
                _position.entryFundingRate
            );

            if (!hasProfit && _position.collateral < delta) {
                if (_raise) {
                    revert("Vault: Losses exceed collateral");
                }
                
                return (LIQUIDATE_FEE_EXCEED, migrateFeeUsd);
            }

            uint256 remainingCollateral = _position.collateral;

            if (!hasProfit) {
                remainingCollateral = _position.collateral - delta;
            }

            if (_position.collateral * priceManager.maxLeverage(_indexToken) < _position.size * MIN_LEVERAGE) {
                if (_raise) {
                    revert("Vault: Max leverage exceeded");
                }
            }

            return _checkMaxThreshold(remainingCollateral, _position.size, migrateFeeUsd, _indexToken, _raise);
        } else {
            return (LIQUIDATE_NONE_EXCEED, 0);
        }
    }

    function validatePositionData(
        bool _isLong,
        address _indexToken,
        OrderType _orderType,
        uint256 _indexTokenPrice,
        uint256[] memory _params,
        bool _raise
    ) external view override returns (bool) {
        if (_raise && _params.length != 8) {
            revert("Invalid params length, must be 8");
        }

        bool orderTypeFlag;
        uint256 marketSlippage;

        if (_params[5] > 0) {
            uint256 indexTokenPrice = _indexTokenPrice == 0 ? priceManager.getLastPrice(_indexToken) : _indexTokenPrice;

            if (_isLong) {
                if (_orderType == OrderType.LIMIT && _params[2] > 0) {
                    orderTypeFlag = true;
                } else if (_orderType == OrderType.STOP && _params[3] > 0) {
                    orderTypeFlag = true;
                } else if (_orderType == OrderType.STOP_LIMIT && _params[2] > 0 && _params[3] > 0) {
                    orderTypeFlag = true;
                } else if (_orderType == OrderType.MARKET) {
                    marketSlippage = _getMarketSlippage(_params[1]);
                    checkSlippage(_isLong, _getFirstParams(_params), marketSlippage, indexTokenPrice);
                    orderTypeFlag = true;
                }
            } else {
                if (_orderType == OrderType.LIMIT && _params[2] > 0) {
                    orderTypeFlag = true;
                } else if (_orderType == OrderType.STOP && _params[3] > 0) {
                    orderTypeFlag = true;
                } else if (_orderType == OrderType.STOP_LIMIT && _params[2] > 0 && _params[3] > 0) {
                    orderTypeFlag = true;
                } else if (_orderType == OrderType.MARKET) {
                    marketSlippage = _getMarketSlippage(_params[1]);
                    checkSlippage(_isLong, _getFirstParams(_params), marketSlippage, indexTokenPrice);
                    orderTypeFlag = true;
                }
            }
        } else {
            orderTypeFlag = true;
        }
        
        if (_raise) {
            require(orderTypeFlag, "Invalid positionData");
        }

        return (orderTypeFlag);
    }

    function _getMarketSlippage(uint256 _slippage) internal view returns (uint256) {
        uint256 defaultSlippage = settingsManager.positionDefaultSlippage();
        return _slippage >= BASIS_POINTS_DIVISOR || _slippage < defaultSlippage ? defaultSlippage : _slippage;
    }

    function validateTrailingStopInputData(
        bytes32 _key,
        bool _isLong,
        uint256[] memory _params,
        uint256 _indexPrice
    ) external view override returns (bool) {
        require(_params[1] > 0 && _params[1] <= positionKeeper.getPositionSize(_key), "Trailing size should be smaller than position size");
        
        if (_isLong) {
            require(_params[4] > 0 && _params[3] > 0 && _params[3] <= _indexPrice, "Invalid trailing data");
        } else {
            require(_params[4] > 0 && _params[3] > 0 && _params[3] >= _indexPrice, "Invalid trailing data");
        }

        if (_params[2] == TRAILING_STOP_TYPE_PERCENT) {
            require(_params[4] < BASIS_POINTS_DIVISOR, "Percent cant exceed 100%");
        } else {
            if (_isLong) {
                require(_params[4] < _indexPrice, "Step amount cant exceed price");
            }
        }

        return true;
    }

    function validateTrailingStopPrice(
        bool _isLong,
        bytes32 _key,
        bool _raise,
        uint256 _indexPrice
    ) external view override returns (bool) {
        OrderInfo memory order = positionKeeper.getOrder(_key);
        uint256 stopPrice;

        if (_isLong) {
            if (order.stepType == TRAILING_STOP_TYPE_AMOUNT) {
                stopPrice = order.stpPrice + order.stepAmount;
            } else {
                stopPrice = (order.stpPrice * BASIS_POINTS_DIVISOR) / (BASIS_POINTS_DIVISOR - order.stepAmount);
            }
        } else {
            if (order.stepType == TRAILING_STOP_TYPE_AMOUNT) {
                stopPrice = order.stpPrice - order.stepAmount;
            } else {
                stopPrice = (order.stpPrice * BASIS_POINTS_DIVISOR) / (BASIS_POINTS_DIVISOR + order.stepAmount);
            }
        }

        bool flag;

        if (
            _isLong &&
            order.status == OrderStatus.PENDING &&
            order.positionType == POSITION_TRAILING_STOP &&
            stopPrice <= _indexPrice
        ) {
            flag = true;
        } else if (
            !_isLong &&
            order.status == OrderStatus.PENDING &&
            order.positionType == POSITION_TRAILING_STOP &&
            stopPrice >= _indexPrice
        ) {
            flag = true;
        }

        if (_raise) {
            require(flag, "Incorrect price");
        }

        return flag;
    }

    function validateTrigger(
        bytes32 _key,
        uint256 _indexPrice
    ) external view override returns (uint8) {
        return _validateTrigger(
            IRouter(router).getBond(_key).isLong,
            _indexPrice,
            positionKeeper.getOrder(_key)
        );
    }

    function validateTrigger(
        bool _isLong,
        uint256 _indexPrice,
        OrderInfo memory _order
    ) external pure override returns (uint8) {
        return _validateTrigger(
            _isLong,
            _indexPrice,
            _order
        );
    }

    function _validateTrigger(
        bool _isLong,
        uint256 _indexPrice,
        OrderInfo memory _order
    ) internal pure returns (uint8) {
        uint8 statusFlag;

        if (_order.status == OrderStatus.PENDING) {
            if (_order.positionType == POSITION_LIMIT) {
                if (_isLong && _order.lmtPrice >= _indexPrice) {
                    statusFlag = ORDER_FILLED;
                } else if (!_isLong && _order.lmtPrice <= _indexPrice) {
                    statusFlag = ORDER_FILLED;
                } else {
                    statusFlag = ORDER_NOT_FILLED;
                }
            } else if (_order.positionType == POSITION_STOP_MARKET) {
                if (_isLong && _order.stpPrice <= _indexPrice) {
                    statusFlag = ORDER_FILLED;
                } else if (!_isLong && _order.stpPrice >= _indexPrice) {
                    statusFlag = ORDER_FILLED;
                } else {
                    statusFlag = ORDER_NOT_FILLED;
                }
            } else if (_order.positionType == POSITION_STOP_LIMIT) {
                if (_isLong && _order.stpPrice <= _indexPrice) {
                    statusFlag = ORDER_FILLED;
                } else if (!_isLong && _order.stpPrice >= _indexPrice) {
                    statusFlag = ORDER_FILLED;
                } else {
                    statusFlag = ORDER_NOT_FILLED;
                }
            } else if (_order.positionType == POSITION_TRAILING_STOP) {
                if (_isLong && _order.stpPrice >= _indexPrice) {
                    statusFlag = ORDER_FILLED;
                } else if (!_isLong && _order.stpPrice <= _indexPrice) {
                    statusFlag = ORDER_FILLED;
                } else {
                    statusFlag = ORDER_NOT_FILLED;
                }
            }
        } else {
            statusFlag = ORDER_NOT_FILLED;
        }
        
        return statusFlag;
    }

    function validateSizeCollateralAmount(uint256 _size, uint256 _collateral) external pure override {
        _validateSizeCollateralAmount(_size, _collateral);
    }

    function _validateSizeCollateralAmount(uint256 _size, uint256 _collateral) internal pure {
        require(_size >= _collateral, "Position size should be greater than collateral");
    }

    function _checkMaxThreshold(
        uint256 _collateral,
        uint256 _size,
        uint256 _marginFees,
        address _indexToken,
        bool _raise
    ) internal view returns (uint256, uint256) {
        if (_collateral < _marginFees) {
            if (_raise) {
                revert("Vault: Fees exceed collateral");
            }
            // cap the fees to the remainingCollateral
            return (LIQUIDATE_FEE_EXCEED, _collateral);
        }

        if (_collateral < _marginFees + settingsManager.liquidationFeeUsd()) {
            if (_raise) {
                revert("Vault: Liquidation fees exceed collateral");
            }
            return (LIQUIDATE_FEE_EXCEED, _marginFees);
        }

        if (
            _collateral - (_marginFees + settingsManager.liquidationFeeUsd()) <
            (_size * (BASIS_POINTS_DIVISOR - settingsManager.liquidateThreshold(_indexToken))) / BASIS_POINTS_DIVISOR
        ) {
            if (_raise) {
                revert("Vault: Max threshold exceeded");
            }
            
            return (LIQUIDATE_THRESHOLD_EXCEED, _marginFees + settingsManager.liquidationFeeUsd());
        }

        return (LIQUIDATE_NONE_EXCEED, _marginFees);
    }

    function setPriceManagerForDev(address _priceManager) external onlyOwner {
       priceManager = IPriceManager(_priceManager);
    }

    function setSettingsManagerForDev(address _sm) external onlyOwner {
        settingsManager = ISettingsManager(_sm);
    }
    

    function validatePositionSize(bytes32 _key, uint256 _txType, address _account) external view returns (bool) {
        if (_txType == ADD_POSITION || 
            _txType == ADD_COLLATERAL ||
            _txType == REMOVE_COLLATERAL ||
            _txType == ADD_TRAILING_STOP ||
            _txType == UPDATE_TRAILING_STOP || 
            _txType == CLOSE_POSITION) {
            Position memory position = positionKeeper.getPosition(_key);
            require(position.owner == _account, "Invalid positionOwner");
            require(position.size > 0, "Position not initialized");
        }

        return true;
    }

    function validateAddCollateral(
        uint256 _amountIn,
        address _collateralToken,
        uint256 _collateralPrice,
        bytes32 _key
    ) external view returns (uint256) {
        Position memory position = positionKeeper.getPosition(_key);

        return _validateAddCollateral(
            position.size, 
            position.collateral, 
            _amountIn,
            _collateralToken,
            _collateralPrice
        );
    }

    function validateAmountIn(
        address _collateralToken,
        uint256 _amountIn,
        uint256 _collateralPrice
    ) external view returns (uint256) {
        return _validateAmountIn(
            _collateralToken,
            _amountIn,
            _collateralPrice
        );
    }

    function _validateAmountIn(
        address _collateralToken,
        uint256 _amountIn,
        uint256 _collateralPrice
    ) internal view returns (uint256){
        uint256 amountInUSD = priceManager.fromTokenToUSD(_collateralToken, _amountIn, _collateralPrice);
        require(amountInUSD > 0, "AmountIn should not be ZERO");
        return amountInUSD;
    }

    function validateAddCollateral(
        uint256 _positionSize, 
        uint256 _positionCollateral, 
        uint256 _amountIn,
        address _collateralToken,
        uint256 _collateralPrice
    ) external view returns (uint256) {
        return _validateAddCollateral(
            _positionSize, 
            _positionCollateral, 
            _amountIn,
            _collateralToken,
            _collateralPrice
        );
    }

    function _validateAddCollateral(
        uint256 _positionSize, 
        uint256 _positionCollateral, 
        uint256 _amountIn,
        address _collateralToken,
        uint256 _collateralPrice
    ) internal view returns (uint256) {
        uint256 amountInUSD = _validateAmountIn(_collateralToken, _amountIn, _collateralPrice);
        _validateSizeCollateralAmount(_positionSize, _positionCollateral + amountInUSD);
        return amountInUSD;
    }

    function validateRemoveCollateral(
        uint256 _amountIn, 
        bool _isLong,
        address _indexToken,
        uint256 _indexPrice,
        bytes32 _key
    ) external view {
        Position memory position = positionKeeper.getPosition(_key);
        require(_amountIn <= position.collateral, "Insufficient position collateral");
        position.collateral -= _amountIn;
        _validateRemoveCollateral(
            _amountIn, 
            _isLong,
            _indexToken,
            _indexPrice,
            position
        );
    }

    function validateRemoveCollateral(
        uint256 _amountIn, 
        bool _isLong,
        address _indexToken,
        uint256 _indexPrice,
        Position memory _position
    ) external view {
        _validateRemoveCollateral(
            _amountIn, 
            _isLong,
            _indexToken,
            _indexPrice,
            _position
        );
    }

    function _validateRemoveCollateral(
        uint256 _amountIn, 
        bool _isLong,
        address _indexToken,
        uint256 _indexPrice,
        Position memory _position
    ) internal view {
        _validateSizeCollateralAmount(_position.size, _position.collateral);
        require(_amountIn <= _position.reserveAmount, "Insufficient reserved collateral");
        require(_position.totalFee <= _position.collateral, "Insufficient position collateral, fee exceeded");
        _validateLiquidation(_position.owner, _indexToken, _isLong, true, _indexPrice, _position);
    }

    function beforeDecreasePosition(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _sizeDelta,
        uint256 _indexPrice,
        bool _isInternal
    ) external view returns (uint256[4] memory, bool, bool, Position memory) {
        if (_isInternal) {
            require(msg.sender == positionHandler, "Forbidden: Not positionHandler");
        }

        Position memory position;

        //Scope to avoid stack too deep error
        {
            bytes32 key = _getPositionKey(_account, _indexToken, _isLong, _posId);
            position = positionKeeper.getPosition(key);
        }

        return _beforeDecreasePosition(
            _indexToken,
            _sizeDelta,
            _isLong,
            _indexPrice,
            position,
            _isInternal
        );
    }

    function _beforeDecreasePosition(
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _indexPrice,
        Position memory _position,
        bool _isInternal
    ) internal view returns (uint256[4] memory, bool, bool, Position memory) {
        require(_position.size > 0, "Insufficient position size, ZERO");

        if (!_isInternal) {
            require(positionKeeper.reservedAmounts(_indexToken, _isLong) >= _sizeDelta, "Vault: reservedAmounts exceeded");
        }

        uint256 decreaseReserveAmount = (_position.reserveAmount * _sizeDelta) / _position.size;
        require(decreaseReserveAmount <= _position.reserveAmount, "Insufficient position reserve amount");
        _position.reserveAmount -= decreaseReserveAmount;
        uint256[4] memory posData;
        bool hasProfit;

        {
            (posData, hasProfit) = _reduceCollateral(
                _indexToken, 
                _sizeDelta, 
                _isLong, 
                _indexPrice, 
                _position
            );
        }

        if (_position.size != _sizeDelta) {
            _position.entryFundingRate = settingsManager.cumulativeFundingRates(_indexToken, _isLong);
            require(_sizeDelta <= _position.size, "Insufficient position size, exceeded");
            _position.size -= _sizeDelta;
            _validateSizeCollateralAmount(_position.size, _position.collateral);
            _validateLiquidation(_position.owner, _indexToken, _isLong, true, _indexPrice, _position);
        } else {
            _position.size = 0;
        }

        return (posData, hasProfit, _position.size != _sizeDelta, _position);
    }

    function _reduceCollateral(
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _indexPrice, 
        Position memory _position
    ) internal view returns (uint256[4] memory, bool) {
        bool hasProfit;
        uint256 adjustedDelta;

        //Scope to avoid stack too deep error
        {
            (bool _hasProfit, uint256 delta) = priceManager.getDelta(
                _indexToken,
                _position.size,
                _position.averagePrice,
                _isLong,
                _indexPrice
            );
            hasProfit = _hasProfit;
            //Calculate the proportional change in PNL = leverage * delta
            adjustedDelta = (_sizeDelta * delta) / _position.size;
        }

        uint256 usdOut;

        if (adjustedDelta > 0) {
            if (hasProfit) {
                usdOut = adjustedDelta;
                _position.realisedPnl += int256(adjustedDelta);
            } else {
                require(_position.collateral >= adjustedDelta, "Insufficient position collateral");
                _position.collateral -= adjustedDelta;
                _position.realisedPnl -= int256(adjustedDelta);
            }
        }

        uint256 collateralDelta = (_position.collateral * _sizeDelta) / _position.size;

        // If the position will be closed, then transfer the remaining collateral out
        if (_position.size == _sizeDelta) {
            usdOut += _position.collateral;
            _position.collateral = 0;
        } else {
            // Reduce the position's collateral by collateralDelta, transfer collateralDelta out
            usdOut += collateralDelta;
            _position.collateral -= collateralDelta;
        }

        uint256 fee;

        //Scope to avoid stack too deep error
        {
            //Calculate fee for closing position
            fee = _calculateMarginFee(_indexToken, _isLong, _sizeDelta, _position);
            //Add previous openning fee
            fee += _position.totalFee;
            _position.totalFee = 0;
        }

        
        // If the usdOut is more or equal than the fee then deduct the fee from the usdOut directly
        // else deduct the fee from the position's collateral
        if (usdOut < fee) {
            require(fee <= _position.collateral, "Insufficient position collateral to deduct fee");
            _position.collateral -= fee;
        }

        _validateDecreasePosition(_indexToken, _isLong, true, _indexPrice, _position);
        return ([usdOut, fee, collateralDelta, adjustedDelta], hasProfit);
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

    function _getFirstParams(uint256[] memory _params) internal pure returns (uint256) {
        return _params[0];
    }
}