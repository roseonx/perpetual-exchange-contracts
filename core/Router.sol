// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./BasePosition.sol";
import "./BaseRouter.sol";
import "../swap/interfaces/ISwapRouter.sol";
import "./interfaces/IRouter.sol";

import {Position, OrderInfo, VaultBond, OrderStatus} from "../constants/Structs.sol";

contract Router is BaseRouter, IRouter, ReentrancyGuard {
    mapping(bytes32 => PositionBond) private bonds;

    mapping(bytes32 => PrepareTransaction) private txns;
    mapping(bytes32 => mapping(uint256 => TxDetail)) private txnDetails;

    address public triggerOrderManager;
    ISwapRouter public swapRouter;

    event SetTriggerOrderManager(address triggerOrderManager);
    event SetSwapRouter(address swapRouter);
    event CreatePrepareTransaction(
        address indexed account,
        bool isLong,
        uint256 posId,
        uint256 txType,
        uint256[] params,
        address[] path,
        bytes32 indexed key,
        bool isFastExecute
    );
    event ExecutionReverted(
        bytes32 key, 
        address account, 
        bool isLong, 
        uint256 posId, 
        uint256[] params, 
        uint256[] prices,
        address[] collateralPath,
        uint256 txType,
        string err
    );

    modifier preventTradeForForexCloseTime(address _token) {
        if (priceManager.isForex(_token)) {
            require(!settingsManager.pauseForexForCloseTime() , "PTFCT"); //Prevent trade for forex close time
        }
        _;
    }

    constructor(
        address _vault, 
        address _positionHandler, 
        address _positionKeeper,
        address _settingsManager,
        address _priceManager,
        address _vaultUtils,
        address _triggerOrderManager,
        address _swapRouter
    ) BaseRouter(_vault, _positionHandler, _positionKeeper, _settingsManager, _priceManager, _vaultUtils) {
        _setTriggerOrderManager(_triggerOrderManager);
        _setSwapRouter(_swapRouter);
    }

    //Config functions
    function setTriggerOrderManager(address _triggerOrderManager) external onlyOwner {
        _setTriggerOrderManager(_triggerOrderManager);
    }

    function setSwapRouter(address _swapRouter) external onlyOwner {
        _setSwapRouter(_swapRouter);
    }

    function _setTriggerOrderManager(address _triggerOrderManager) internal {
        triggerOrderManager = _triggerOrderManager;
        emit SetTriggerOrderManager(_triggerOrderManager);
    }

    function _setSwapRouter(address _swapRouter) private {
        swapRouter = ISwapRouter(_swapRouter);
        emit SetSwapRouter(_swapRouter);
    }
    //End config functions

    function openNewPosition(
        bool _isLong,
        OrderType _orderType,
        address _refer,
        uint256[] memory _params,
        address[] memory _path
    ) external payable nonReentrant preventTradeForForexCloseTime(_getFirstPath(_path)) {
        require(!settingsManager.isEmergencyStop(), "EMSTP"); //Emergency stopped
        _prevalidate(_path, _getLastParams(_params));

        if (_orderType != OrderType.MARKET) {
            require(msg.value == settingsManager.triggerGasFee(), "IVLTGF"); //Invalid triggerGasFee
            payable(settingsManager.getFeeManager()).transfer(msg.value);
        }

        uint256 txType;

        //Scope to avoid stack too deep error
        {
            txType = _getTransactionTypeFromOrder(_orderType);
            _verifyParamsLength(txType, _params);
        }

        uint256 posId;
        Position memory position;
        OrderInfo memory order;

        //Scope to avoid stack too deep error
        {
            posId = positionKeeper.lastPositionIndex(msg.sender);
            (position, order) = positionKeeper.getPositions(msg.sender, _getFirstPath(_path), _isLong, posId);
            position.owner = msg.sender;
            position.refer = _refer;

            order.pendingCollateral = _params[4];
            order.pendingSize = _params[5];
            order.collateralToken = _path[1];
            order.status = OrderStatus.PENDING;
        }

        bytes32 key;

        //Scope to avoid stack too deep error
        {
            key = _getPositionKey(msg.sender, _getFirstPath(_path), _isLong, posId);
        }

        bool isFastExecute;
        uint256[] memory prices;

        //Scope to avoid stack too deep error
        {
            (isFastExecute, prices) = _getPricesAndCheckFastExecute(_path);
            vaultUtils.validatePositionData(
                _isLong, 
                _getFirstPath(_path), 
                _orderType, 
                _getFirstParams(prices), 
                _params, 
                true
            );

            _transferAssetToVault(
                msg.sender,
                _path[1],
                order.pendingCollateral,
                key,
                txType
            );

            PositionBond storage bond;
            bond = bonds[key];
            bond.owner = position.owner;
            bond.posId = posId;
            bond.isLong = _isLong;
            bond.indexToken = _getFirstPath(_path);
            txnDetails[key][txType].params = _params;
            bond.leverage = order.pendingSize * BASIS_POINTS_DIVISOR / order.pendingCollateral;
        }

        if (_orderType == OrderType.MARKET) {
            order.positionType = POSITION_MARKET;
        } else if (_orderType == OrderType.LIMIT) {
            order.positionType = POSITION_LIMIT;
            order.lmtPrice = _params[2];
        } else if (_orderType == OrderType.STOP) {
            order.positionType = POSITION_STOP_MARKET;
            order.stpPrice = _params[3];
        } else if (_orderType == OrderType.STOP_LIMIT) {
            order.positionType = POSITION_STOP_LIMIT;
            order.lmtPrice = _params[2];
            order.stpPrice = _params[3];
        } else {
            revert("IVLOT"); //Invalid order type
        }

        if (isFastExecute && _orderType == OrderType.MARKET) {
            _openNewMarketPosition(
                key, 
                _path,
                prices, 
                _params, 
                order
            );
        } else {
            _createPrepareTransaction(
                msg.sender,
                _isLong,
                posId,
                txType,
                _params,
                _path,
                false
            );
        }

        _processOpenNewPosition(
            txType,
            key,
            abi.encode(position, order),
            _params,
            prices,
            _path,
            isFastExecute,
            true
        );
    }

    function _openNewMarketPosition(
        bytes32 _key, 
        address[] memory _path,
        uint256[] memory _prices, 
        uint256[] memory _params,
        OrderInfo memory _order
    ) internal {
        uint256 pendingCollateral;
        bool isSwapSuccess = true;
                    
        if (_isSwapRequired(_path)) {
            uint256 swapAmountOut;

            //Scope to avoid stack too deep error
            {
                pendingCollateral = _order.pendingCollateral;
                _order.pendingCollateral = 0;
                (, uint256 amountOutMin) = _extractDeadlineAndAmountOutMin(CREATE_POSITION_MARKET, _params, true);
                (isSwapSuccess, swapAmountOut) = _processSwap(
                    _key,
                    pendingCollateral,
                    amountOutMin,
                    CREATE_POSITION_MARKET,
                    _path
                );
            }
        } 

        if (!isSwapSuccess) {
            _order.status = OrderStatus.CANCELED;
            _revertExecute(
                _key,
                CREATE_POSITION_MARKET,
                true,
                _params,
                _prices,
                _path,
                "SWF" //Swap failed
            );

            return;
        }

        _order.status = OrderStatus.FILLED;
    }

    function _processOpenNewPosition(
        uint256 _txType,
        bytes32 _key, 
        bytes memory _data, 
        uint256[] memory _params, 
        uint256[] memory _prices, 
        address[] memory _path,
        bool _isFastExecute,
        bool _isNewPosition
    ) internal {
        positionHandler.openNewPosition(
            _key,
            bonds[_key].isLong,
            bonds[_key].posId,
            _isSwapRequired(_path) ? _path.length - 1 : 1,
            _data,
            _params, 
            _prices,
            _path,
            _isFastExecute,
            _isNewPosition
        );

        if (_txType == CREATE_POSITION_MARKET && _isFastExecute) {
            delete txns[_key];
            delete txnDetails[_key][CREATE_POSITION_MARKET];
        }
    }

    function _revertExecute(
        bytes32 _key, 
        uint256 _txType,
        bool _isTakeAssetBack,
        uint256[] memory _params, 
        uint256[] memory _prices, 
        address[] memory _path,
        string memory err
    ) internal {
        if (_isTakeAssetBack) {
            _takeAssetBack(_key, _txType);
        }

        if (_txType == CREATE_POSITION_MARKET || 
            _txType == ADD_TRAILING_STOP || 
            _isDelayPosition(_txType)) {
                Position memory position = positionKeeper.getPosition(_key);
                positionHandler.modifyPosition(
                    bonds[_key].owner,
                    bonds[_key].isLong,
                    bonds[_key].posId,
                    REVERT_EXECUTE,
                    abi.encode(_txType, position),
                    _path,
                    _prices
                );
        }

        _clearPrepareTransaction(_key, _txType);

        emit ExecutionReverted(
            _key,
            bonds[_key].owner,
            bonds[_key].isLong,
            bonds[_key].posId,
            _params,
            _prices,
            _path,
            _txType, 
            err
        );
    }

    function addOrRemoveCollateral(
        bool _isLong,
        uint256 _posId,
        bool _isPlus,
        uint256[] memory _params,
        address[] memory _path
    ) external override nonReentrant preventTradeForForexCloseTime(_getFirstPath(_path)) {
        if (_isPlus) {
            _verifyParamsLength(ADD_COLLATERAL, _params);
            _prevalidate(_path, _getLastParams(_params));
        } else {
            _verifyParamsLength(REMOVE_COLLATERAL, _params);
            _prevalidate(_path, 0, false);
        }

        bytes32 key;
        bool isFastExecute; 
        uint256[] memory prices;

        //Scope to avoid stack too deep error
        {
            key = _getPositionKey(msg.sender, _getFirstPath(_path), _isLong, _posId);
            (isFastExecute, prices) = _getPricesAndCheckFastExecute(_path);
        }

        if (_isPlus) {
            vaultUtils.validateAddCollateral(
                _getFirstParams(_params), 
                _getLastPath(_path), 
                _getLastParams(prices),
                key
            );
        } else {
            vaultUtils.validateRemoveCollateral(
                _getFirstParams(_params), 
                _isLong, 
                _getFirstPath(_path), 
                _getFirstParams(prices), 
                key
            );
        }

        _modifyPosition(
            msg.sender,
            _isLong,
            _posId,
            _isPlus ? ADD_COLLATERAL : REMOVE_COLLATERAL,
            _isPlus ? true : false,
            _params,
            prices,
            _path,
            isFastExecute
        );
    }

    function addPosition(
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params,
        address[] memory _path
    ) external payable override nonReentrant preventTradeForForexCloseTime(_getFirstPath(_path)) {
        require(msg.value == settingsManager.triggerGasFee(), "IVLTGF");
        _verifyParamsLength(ADD_POSITION, _params);
        _prevalidate(_path, _getLastParams(_params));
        payable(settingsManager.getFeeManager()).transfer(msg.value);

        //Fast execute disabled for adding position
        (, uint256[] memory prices) = _getPricesAndCheckFastExecute(_path);
        _modifyPosition(
            msg.sender,
            _isLong,
            _posId,
            ADD_POSITION,
            true,
            _params,
            prices,
            _path,
            false
        );
    }

    function addTrailingStop(
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params,
        address[] memory _path
    ) external payable override nonReentrant {
        require(msg.value == settingsManager.triggerGasFee(), "IVLTGF"); //Invalid triggerFasFee
        _prevalidate(_path, 0, false);
        _verifyParamsLength(ADD_TRAILING_STOP, _params);
        payable(settingsManager.getFeeManager()).transfer(msg.value);

       //Fast execute for adding trailing stop
        (, uint256[] memory  prices) = _getPricesAndCheckFastExecute(_path);
        _modifyPosition(
            msg.sender, 
            _isLong, 
            _posId,
            ADD_TRAILING_STOP,
            false,
            _params,
            prices,
            _path,
            true
        );
    }

    function updateTrailingStop(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _indexPrice
    ) external override nonReentrant {
        _prevalidate(_indexToken);
        require(_isExecutor(msg.sender) || msg.sender == _account, "IVLPO"); //Invalid positionOwner
        uint256[] memory prices = new uint256[](1);
        bool isFastExecute;

        if (!_isExecutor(msg.sender)) {
            uint256 indexPrice;
            (isFastExecute, indexPrice) = _getPriceAndCheckFastExecute(_indexToken);
            prices[0] = indexPrice;
        } else {
            prices[0] = _indexPrice;
        }
        
        _modifyPosition(
            _account, 
            _isLong, 
            _posId,
            UPDATE_TRAILING_STOP,
            false,
            new uint256[](0),
            prices,
            _getSinglePath(_indexToken),
            _isExecutor(msg.sender) ? true : isFastExecute
        );
    }

    function cancelPendingOrder(
        address _indexToken, 
        bool _isLong, 
        uint256 _posId
    ) external override nonReentrant {
        _prevalidate(_indexToken);
        address[] memory path = new address[](1);
        path[0] = _indexToken;

        //Fast execute for canceling pending order
        _modifyPosition(
            msg.sender, 
            _isLong, 
            _posId,
            CANCEL_PENDING_ORDER,
            false,
            new uint256[](0),
            new uint256[](0),
            path,
            true
        );
    }

    /*
    @dev: Trigger position from triggerOrderManager
    */
    function triggerPosition(
        bytes32 _key,
        bool _isFastExecute,
        uint256 _txType,
        address[] memory _path,
        uint256[] memory _prices
    ) external override {
        require(msg.sender == address(triggerOrderManager), "FBD"); //Forbidden
        _modifyPosition(
            bonds[_key].owner, 
            bonds[_key].isLong, 
            bonds[_key].posId,
            _txType,
            false,
            _getParams(_key, _txType),
            _prices,
            _path,
            msg.sender == address(triggerOrderManager) ? true : _isFastExecute
        );
    }

    function closePosition(
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params,
        address[] memory _path
    ) external override nonReentrant preventTradeForForexCloseTime(_getFirstPath(_path)) {
        _prevalidate(_path, 0, false);
        _verifyParamsLength(CLOSE_POSITION, _params);
        (bool isFastExecute, uint256[] memory prices) = _getPricesAndCheckFastExecute(_path);

        _modifyPosition(
            msg.sender, 
            _isLong, 
            _posId,
            CLOSE_POSITION,
            false,
            _params,
            prices,
            _path,
            isFastExecute
        );
    }

    function setPriceAndExecute(bytes32 _key, uint256 _txType, uint256[] memory _prices) external {
        require(_isExecutor(msg.sender) || msg.sender == address(positionHandler), "FBD"); //Forbidden
        address[] memory path = getExecutePath(_key, _txType);
        require(path.length > 0 && path.length == _prices.length, "IVLAL"); //Invalid array length
        _setPriceAndExecute(_key, _txType, path, _prices);
    }

    function revertExecution(
        bytes32 _key, 
        uint256 _txType,
        address[] memory _path,
        uint256[] memory _prices, 
        string memory err
    ) external override {
        require(_isExecutor(msg.sender) || msg.sender == address(positionHandler), "FBD"); //Forbidden
        require(txns[_key].status == TRANSACTION_STATUS_PENDING, "IVLPTS/NPND"); //Invalid preapre transaction status, must pending
        require(_path.length > 0 && _prices.length == _path.length, "IVLAL"); //Invalid array length
        txns[_key].status == TRANSACTION_STATUS_EXECUTE_REVERTED;

        _revertExecute(
            _key, 
            _txType,
            _isTakeAssetBackRequired(_txType),
            _getParams(_key, _txType), 
            _prices, 
            _path,
            err
        );
    }

    function _isTakeAssetBackRequired(uint256 _txType) internal pure returns (bool) {
        return (_txType == CREATE_POSITION_MARKET || 
            _isDelayPosition(_txType) || 
            _txType == ADD_COLLATERAL || 
            _txType == ADD_POSITION
        );
    }

    function _modifyPosition(
        address _account,
        bool _isLong,
        uint256 _posId,
        uint256 _txType,
        bool _isTakeAssetRequired,
        uint256[] memory _params,
        uint256[] memory _prices,
        address[] memory _path,
        bool _isFastExecute
    ) internal {
        require(!settingsManager.isEmergencyStop(), "EMS"); //Emergency stopped
        bytes32 key;

        //Scope to avoid stack too deep error
        {
            key = _getPositionKey(_account, _getFirstPath(_path), _isLong, _posId);
            require(bonds[key].owner == _account, "IVLBO"); //Invalid bond owner
        }

        if (_txType == LIQUIDATE_POSITION) {
            positionHandler.modifyPosition(
                _account, 
                _isLong,
                _posId,
                LIQUIDATE_POSITION,
                abi.encode(positionKeeper.getPosition(key)),
                _path,
                _prices
            );

            return;
        } 

        if (_txType == ADD_POSITION || 
            _txType == ADD_COLLATERAL ||
            _txType == REMOVE_COLLATERAL ||
            _txType == ADD_TRAILING_STOP ||
            _txType == UPDATE_TRAILING_STOP || 
            _txType == CLOSE_POSITION) {
            require(positionKeeper.getPositionSize(key) > 0, "IVLPS/NI"); //Invalid position, not initialized
        }

        //Transfer collateral to vault if required
        if (_isTakeAssetRequired) {
            require(_params.length > 0 && _path.length > 1, "IVLPAPL"); //Invalid path and params length
            _transferAssetToVault(
                _account,
                _path[1],
                _getFirstParams(_params),
                key,
                _txType
            );
        }

        if (!_isFastExecute) {
            _createPrepareTransaction(
                _account,
                _isLong,
                _posId,
                _txType,
                _params,
                _path,
                _isFastExecute
            );
        } else {
            bytes memory data;
            uint256 amountIn = _params.length == 0 ? 0 : _getFirstParams(_params);
            bool isSwapSuccess = true;

            //Scope to avoid stack too deep error
            {
                uint256 swapAmountOut;

                if (_isSwapRequired(_path) && _isRequiredAmountOutMin(_txType)) {
                    (isSwapSuccess, swapAmountOut) = _processSwap(
                        key,
                        amountIn,
                        _getLastParams(_params), //amountOutMin
                        _txType,
                        _path
                    );
                    amountIn = priceManager.fromTokenToUSD(
                        _getLastPath(_path), 
                        swapAmountOut, 
                        _getLastParams(_prices)
                    );
                    require(amountIn > 0, "IVLAMIAS/Z"); //Invalid amount in after swap, zero USD 
                }
            }

            if (!isSwapSuccess) {
                _revertExecute(
                    key,
                    _txType,
                    true,
                    _params,
                    _prices,
                    _path,
                    "SWF"
                );

                return;
            }

            bool isDelayPosition = _isDelayPosition(_txType);

            if (_txType == ADD_COLLATERAL || _txType == REMOVE_COLLATERAL) {
                require(amountIn > 0, "IVLAMI/Z"); //Invalid amount in, zero USD
                data = abi.encode(amountIn, positionKeeper.getPosition(key));
            } else if (_txType == ADD_TRAILING_STOP) {
                data = abi.encode(_params, positionKeeper.getOrder(key));
            } else if (_txType == UPDATE_TRAILING_STOP) {
                data = abi.encode(positionKeeper.getOrder(key));
            }  else if (_txType == CANCEL_PENDING_ORDER) {
                data = abi.encode(positionKeeper.getOrder(key));
            } else if (_txType == CLOSE_POSITION) {
                Position memory position = positionKeeper.getPosition(key);
                require(_getFirstParams(_params) <= position.size, "ISFPS"); //Insufficient position size
                data = abi.encode(_getFirstParams(_params), position);
            } else if (_txType == ADD_POSITION) {
                require(amountIn > 0, "IVLAMI/Z"); //Invalid amount in, zero USD 
                data = abi.encode(
                    amountIn, 
                    amountIn * bonds[key].leverage / BASIS_POINTS_DIVISOR, 
                    positionKeeper.getPosition(key)
                );
            } else if (_txType == TRIGGER_POSITION || isDelayPosition) {
                (Position memory position, OrderInfo memory order) = positionKeeper.getPositions(key);
                data = abi.encode(position, order);
            } else {
                revert("IVLETXT"); //Invalid execute txType
            }

            positionHandler.modifyPosition(
                _account,
                _isLong,
                _posId,
                isDelayPosition ? TRIGGER_POSITION : _txType,
                data,
                _path,
                _prices
            );

            _clearPrepareTransaction(key, _txType);
        }
    }

    function clearPrepareTransaction(bytes32 _key, uint256 _txType) external {
        require(msg.sender == address(positionHandler), "FBD");
        _clearPrepareTransaction(_key, _txType);
    }

    function _clearPrepareTransaction(bytes32 _key, uint256 _txType) internal {
        delete txns[_key];
        delete txnDetails[_key][_txType];
    }

    function _executeOpenNewMarketPosition(
        bytes32 _key,
        address[] memory _path,
        uint256[] memory _prices,
        uint256[] memory _params
    ) internal {
        require(_params.length > 0 && _path.length > 0 && _path.length == _prices.length, "IVLAL"); //Invalid array length
        bool isValid = vaultUtils.validatePositionData(
            bonds[_key].isLong, 
            _getFirstPath(_path), 
            OrderType.MARKET, 
            _getFirstParams(_prices), 
            _params, 
            false
        );

        if (!isValid) {
            _revertExecute(
                _key,
                CREATE_POSITION_MARKET,
                true,
                _params,
                _prices,
                _path,
                "VLDF" //Validate failed
            );

            return;
        }

        (Position memory position, OrderInfo memory order) = positionKeeper.getPositions(_key);
        _openNewMarketPosition(   
            _key, 
            _path,
            _prices,
            _params, 
            order
        );

        _processOpenNewPosition(
            CREATE_POSITION_MARKET,
            _key,
            abi.encode(position, order),
            _params,
            _prices,
            _path,
            true,
            false
        );
    }

    function _createPrepareTransaction(
        address _account,
        bool _isLong,
        uint256 _posId,
        uint256 _txType,
        uint256[] memory _params,
        address[] memory _path,
        bool isFastExecute
    ) internal {
        bytes32 key = _getPositionKey(_account, _getFirstPath(_path), _isLong, _posId);
        PrepareTransaction storage transaction = txns[key];
        require(transaction.status != TRANSACTION_STATUS_PENDING, "IVLPTS/IP"); //Invalid prepare transaction status, in processing
        transaction.txType = _txType;
        transaction.startTime = block.timestamp;
        transaction.status = TRANSACTION_STATUS_PENDING;
        txnDetails[key][_txType].path = _path;
        txnDetails[key][_txType].params = _params;
        (, uint256 amountOutMin) = _extractDeadlineAndAmountOutMin(_txType, _params, false);

        if (_isSwapRequired(_path) && _isRequiredAmountOutMin(_txType)) {
            require(amountOutMin > 0, "IVLAOM");
        }

        emit CreatePrepareTransaction(
            _account,
            _isLong,
            _posId,
            _txType,
            _params,
            _path,
            key,
            isFastExecute
        );
    }

    function _extractDeadlineAndAmountOutMin(uint256 _type, uint256[] memory _params, bool _isRaise) internal view returns(uint256, uint256) {
        uint256 deadline;
        uint256 amountOutMin;

        if (_type == CREATE_POSITION_MARKET) {
            deadline = _params[6];

            if (_isRaise) {
                require(deadline > 0 && deadline > block.timestamp, "IVLDL"); //Invalid deadline
            }

            amountOutMin = _params[7];
        } else if (_type == REMOVE_COLLATERAL) {
            deadline = _params[1];

            if (_isRaise) {
                require(deadline > 0 && deadline > block.timestamp, "IVLDL"); //Invalid deadline
            }
        } else if (_type == ADD_COLLATERAL) {
            deadline = _params[1];

            if (_isRaise) {
                require(deadline > 0 && deadline > block.timestamp, "IVLDL"); //Invalid deadline
            }

            amountOutMin = _params[2];
        } else if (_type == ADD_POSITION) {
            deadline = _params[2];

            if (_isRaise) {
                require(deadline > 0 && deadline > block.timestamp, "IVLDL"); //Invalid deadline
            }

            amountOutMin = _params[3];
        }

        return (deadline, amountOutMin);
    }

    function _verifyParamsLength(uint256 _type, uint256[] memory _params) internal pure {
        bool isValid;

        if (_type == CREATE_POSITION_MARKET
            || _type == CREATE_POSITION_LIMIT
            || _type == CREATE_POSITION_STOP_MARKET
            || _type == CREATE_POSITION_STOP_LIMIT) {
            isValid = _params.length == 8;
        } else if (_type == ADD_COLLATERAL) {
            isValid = _params.length == 3;
        } else if (_type == REMOVE_COLLATERAL) {
            isValid = _params.length == 2;
        } else if (_type == ADD_POSITION) {
            isValid = _params.length == 4;
        } else if (_type == CLOSE_POSITION) {
            isValid = _params.length == 2;
        } else if (_type == ADD_TRAILING_STOP) {
            isValid = _params.length == 5;
        }

        require(isValid, "IVLPL"); //Invalid params length
    }

    function _setPriceAndExecute(
        bytes32 _key, 
        uint256 _txType,
        address[] memory _path,
        uint256[] memory _prices
    ) internal {
        require(_path.length > 0 && _path.length == _prices.length, "IVLAL"); //Invalid array length
        PositionBond memory bond = bonds[_key];
        require(bond.owner != address(0), "IVLBO"); //Invalid bond owner
        
        if (_txType == LIQUIDATE_POSITION) {
            _modifyPosition(
                bond.owner,
                bond.isLong,
                bond.posId,
                LIQUIDATE_POSITION,
                false,
                new uint256[](0),
                _prices,
                _path,
                true
            );
            txns[_key].status = TRANSACTION_STATUS_EXECUTED;

            return;
        } else if (_txType == CREATE_POSITION_MARKET) {
            _executeOpenNewMarketPosition(
                _key,
                _getPath(_key, CREATE_POSITION_MARKET),
                _prices,
                _getParams(_key, CREATE_POSITION_MARKET) 
            );

            return;
        }

        PrepareTransaction storage txn = txns[_key];

        if (!_isTriggerType(_txType)) {
            require(_txType == txn.txType, "IVLPT/ICRT"); //Invalid parepare transaction, not correct txType
            require(txn.status == TRANSACTION_STATUS_PENDING, "IVLPTS/NP"); //Invalid prepare transaction status, not pending
        }

        txn.status = TRANSACTION_STATUS_EXECUTED;
        (uint256 deadline, ) = _extractDeadlineAndAmountOutMin(_txType, _getParams(_key, _txType), false);

        if (deadline > 0 && deadline <= block.timestamp) {
            _revertExecute(
                _key,
                _txType,
                _isTakeAssetBackRequired(_txType),
                _getParams(_key, _txType),
                _prices,
                _path,
                "DLR" //Deadline reached
            );

            return;
        }

        _modifyPosition(
            bonds[_key].owner,
            bonds[_key].isLong,
            bonds[_key].posId,
            _txType,
            false,
            _getParams(_key, _txType),
            _prices,
            _path,
            true
        );
    }

    function _isTriggerType(uint256 _txType) internal pure returns (bool) {
        return _isDelayPosition(_txType) || _txType == ADD_TRAILING_STOP || _txType == TRIGGER_POSITION;
    }

    function _prevalidate(
        address[] memory _path, 
        uint256 _amountOutMin
    ) internal view {
        _prevalidate(_path, _amountOutMin, true);
    }

    function _prevalidate(
        address[] memory _path, 
        uint256 _amountOutMin,
        bool _isVerifyAmountOutMin
    ) internal view {
        require(_path.length >= 2 && _path.length <= 3, "IVLPTL"); //Invalid path length
        _prevalidate(_getFirstPath(_path));
        address[] memory collateralPath = _cutFrom(_path, 1);
        bool shouldSwap = settingsManager.validateCollateralPathAndCheckSwap(collateralPath);

        if (shouldSwap && collateralPath.length == 2 && _isVerifyAmountOutMin && _amountOutMin == 0) {
            revert("IVLAOM"); //Invalid amountOutMin
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

    function _transferAssetToVault(
        address _account, 
        address _token,
        uint256 _amountIn,
        bytes32 _key,
        uint256 _txType
    ) internal {
        require(_amountIn > 0, "IVLAM"); //Invalid amount
        vault.takeAssetIn(_account, _amountIn, _token, _key, _txType);
    }

    function _isSwapRequired(address[] memory _path) internal pure returns (bool) {
        return _path.length > 2;
    }

    function _valdiateSwapRouter() internal view {
        require(address(swapRouter) != address(0), "IVLSR");
    }

    function _processSwap(
        bytes32 _key,
        uint256 _pendingCollateral, 
        uint256 _amountOutMin,
        uint256 _txType,
        address[] memory _path
    ) internal returns (bool, uint256) {
        require(_pendingCollateral > 0 && _amountOutMin > 0, "IVLSWAM"); //Invalid swap amount
        bool isSwapSuccess; 
        uint256 swapAmountOut;

        {
            (isSwapSuccess, swapAmountOut) = _bondSwap(
                _key, 
                _txType,
                _pendingCollateral,
                _amountOutMin,
                _path[1],
                _getLastPath(_path)
            );
        }

        if (!isSwapSuccess) {
            return (false, _pendingCollateral);
        } 

        return (true, swapAmountOut); 
    }

    function _bondSwap(
        bytes32 _key,
        uint256 _txType,
        uint256 _amountIn, 
        uint256 _amountOutMin,
        address token0,
        address token1
    ) internal returns (bool, uint256) {
        require(token0 != address(0), "ZT0"); //Zero token0
        require(token1 != address(0), "ZT1"); //Zero token1
        require(token0 != token1, "ST0/1"); //Same token0/token1
        _valdiateSwapRouter();

        //Scope to avoid stack too deep error
        {
            try swapRouter.swapFromInternal(
                    bonds[_key].owner,
                    _key,
                    _txType,
                    token0,
                    _amountIn,
                    token1,
                    _amountOutMin
                ) returns (uint256 swapAmountOut) {
                    require(swapAmountOut > 0 && swapAmountOut >= _amountOutMin, "SWF/TLTR"); //Swap failed, too little received
                    return (true, swapAmountOut);
            } catch {
                return (false, _amountIn);
            }
        }
    }

    function _takeAssetBack(bytes32 _key, uint256 _txType) internal {
        vault.takeAssetBack(
            bonds[_key].owner, 
            _key,
            _txType
        );
    }
    
    //
    function getTransaction(bytes32 _key) external view returns (PrepareTransaction memory) {
        return txns[_key];
    }

    function getBond(bytes32 _key) external view returns (PositionBond memory) {
        return bonds[_key];
    }

    function getTxDetail(bytes32 _key, uint256 _txType) external view returns (TxDetail memory) {
        return txnDetails[_key][_txType];
    }

    function getPath(bytes32 _key, uint256 _txType) external view returns (address[] memory) {
        return _getPath(_key, _txType);
    }

    function getParams(bytes32 _key, uint256 _txType) external view returns (uint256[] memory) {
        return _getParams(_key, _txType);
    }
    
    function _getPath(bytes32 _key, uint256 _txType) internal view returns (address[] memory) {
        return txnDetails[_key][_txType].path;
    }

    function getExecutePath(bytes32 _key, uint256 _txType) public view returns (address[] memory) {
        if (_isNotRequirePreparePath(_txType)) {
            return positionKeeper.getPositionFinalPath(_key);
        } else {
            return _getPath(_key, _txType);
        }
    }

    function _isNotRequirePreparePath(uint256 _txType) internal pure returns (bool) {
        return _txType == TRIGGER_POSITION || _txType == REMOVE_COLLATERAL || _txType == LIQUIDATE_POSITION;
    }

    function _getParams(bytes32 _key, uint256 _txType) internal view returns (uint256[] memory) {
        return txnDetails[_key][_txType].params; 
    }

    function _getTransactionTypeFromOrder(OrderType _orderType) internal pure returns (uint256) {
        if (_orderType == OrderType.MARKET) {
            return CREATE_POSITION_MARKET;
        } else if (_orderType == OrderType.LIMIT) {
            return CREATE_POSITION_LIMIT;
        } else if (_orderType == OrderType.STOP) {
            return CREATE_POSITION_STOP_MARKET;
        } else if (_orderType == OrderType.STOP_LIMIT) {
            return CREATE_POSITION_STOP_LIMIT;
        } else {
            revert("IVLOT"); //Invalid order type
        }
    }

    function _isRequiredAmountOutMin(uint256 _txType) internal pure returns (bool) {
        return _isDelayPosition(_txType) || 
            _txType == ADD_COLLATERAL ||
            _txType == ADD_POSITION;
    }

    function _cutFrom(address[] memory _arr, uint256 _startIndex) internal pure returns (address[] memory) {
        require(_arr.length > 1 && _arr.length <= 3, "IVLARL"); //Invalid array length
        address[] memory newArr;

        if (_arr.length == 2 && _startIndex == 1) {
            newArr = new address[](1);
            newArr[0] = _arr[1];
            return newArr;
        }

        require(_startIndex < _arr.length - 1, "IVLARL/S"); //Invalid array length, startIndex
        newArr = new address[](_arr.length - _startIndex);
        uint256 count = 0;

        for (uint256 i = _startIndex; i < _arr.length; i++) {
            newArr[count] = _arr[i];
            count++;
        }

        return newArr;
    }

    function _getSinglePath(address _indexToken) internal pure returns (address[] memory) {
        address[] memory path = new address[](1);
        path[0] = _indexToken;
        return path;
    }
}