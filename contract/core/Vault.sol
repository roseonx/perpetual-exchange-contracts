// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

//import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../tokens/interfaces/IMintable.sol";
import "./interfaces/IPositionKeeper.sol";
import "./interfaces/IPositionHandler.sol";
import "./interfaces/IPriceManager.sol";
import "./interfaces/ISettingsManager.sol";
import "./interfaces/IReferralSystem.sol";
import "./interfaces/IVault.sol";

import {Constants} from "../constants/Constants.sol";
import {OrderStatus, OrderType, ConvertOrder, SwapRequest} from "../constants/Structs.sol";

contract Vault is Constants, ReentrancyGuard, Ownable, IVault {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private collateralTokens;
    EnumerableSet.AddressSet private tradingTokens;
    EnumerableMap.AddressToUintMap private tokenBalances;

    uint256 public aumAddition;
    uint256 public aumDeduction;
    address public immutable ROLP;
    address public immutable RUSD;

    IPositionKeeper public positionKeeper;
    IPositionHandler public positionHandler;
    IPriceManager public priceManager;
    ISettingsManager public settingsManager;
    IReferralSystem public referralSystem;
    address public swapRouter;
    address public positionRouter;
    address public converter;
    address public vaultUtils;

    mapping(address => uint256) public override stakeAmounts;
    mapping(address => uint256) public override poolAmounts;
    mapping(address => uint256) public override reservedAmounts;
    mapping(address => uint256) public override guaranteedAmounts;
    mapping(bytes32 => mapping(uint256 => VaultBond)) public bonds;
    mapping(address => uint256) public lastStakedAt;
    bool public isInitialized;

    event Initialized(IPriceManager priceManager, ISettingsManager settingsManager);
    event UpdatePoolAmount(address indexed token, uint256 amount, uint256 current, bool isPlus);
    event UpdateReservedAmount(address indexed token, uint256 amount, uint256 current, bool isPlus);
    event UpdateGuaranteedAmount(address indexed token, uint256 amount, uint256 current, bool isPlus);

    event DistributeFee(
        bytes32 key,
        address account,
        address refer,
        uint256 fee
    );

    event TakeAssetIn(
        bytes32 key,
        uint256 txType,
        address indexed account, 
        address indexed token,
        uint256 amount,
        uint256 amountInUSD
    );

    event TakeAssetOut(
        bytes32 key,
        address indexed account, 
        address indexed refer, 
        uint256 usdOut, 
        uint256 fee, 
        address token, 
        uint256 tokenAmountOut,
        uint256 tokenPrice
    );

    event TakeAssetBack(
        address indexed account, 
        uint256 amount,
        address token,
        bytes32 key,
        uint256 txType
    );

    event ReduceBond(
        address indexed account, 
        uint256 amount,
        address token,
        bytes32 key,
        uint256 txType
    );

    event TransferBounty(address indexed account, uint256 amount);
    event Stake(address indexed account, address token, uint256 amount, uint256 mintAmount);
    event Unstake(address indexed account, address token, uint256 rolpAmount, uint256 amountOut);
    event SetPositionKeeper(address positionKeeper);
    event SetPositionHandler(address positionHandler);
    event SetPositionRouter(address positionRouter);
    event SetSwapRouter(address swapRouter);
    event SetConverter(address converter);
    event SetVaultUtils(address vaultUtils);
    event RescueERC20(address indexed recipient, address indexed token, uint256 amount);
    event ConvertRUSD(address indexed recipient, address indexed token, uint256 amountIn, uint256 amountOut);
    event SetRefferalSystem(address referralSystem);

    constructor(address _ROLP, address _RUSD) {
        ROLP = _ROLP;
        RUSD = _RUSD;
    }

    //Config functions
    function setPositionRouter(address _router) external onlyOwner {
        require(Address.isContract(_router), "Invalid positionRouter");
        positionRouter = _router;
        emit SetPositionRouter(_router);
    }

    function setPositionKeeper(address _positionKeeper) external onlyOwner {
        require(Address.isContract(_positionKeeper), "Invalid positionKeeper");
        positionKeeper = IPositionKeeper(_positionKeeper);
        emit SetPositionHandler(_positionKeeper);
    }

    function setPositionHandler(address _positionHandler) external onlyOwner {
        require(Address.isContract(_positionHandler), "Invalid positionHandler");
        positionHandler = IPositionHandler(_positionHandler);
        emit SetPositionHandler(_positionHandler);
    }

    function setSwapRouter(address _swapRouter) external onlyOwner {
        require(Address.isContract(_swapRouter), "Invalid swapRouter");
        swapRouter = _swapRouter;
    }

    function setVaultUtils(address _vaultUtils) external onlyOwner {
        require(Address.isContract(_vaultUtils), "Invalid vaultUtils");
        vaultUtils = _vaultUtils;
        emit SetVaultUtils(_vaultUtils);
    }

    function setConverter(address _converter) external onlyOwner {
        converter = _converter;
        emit SetConverter(_converter);
    }

    function setAumAdjustment(uint256 _aumAddition, uint256 _aumDeduction) external onlyOwner {
        aumAddition = _aumAddition;
        aumDeduction = _aumDeduction;
    }

    function addOrRemoveCollateralToken(address _token, bool _isAdd) external onlyOwner {
        if (_isAdd) {
            require(!collateralTokens.contains(_token), "Existed");
            collateralTokens.add(_token);
        } else {
            require(collateralTokens.contains(_token), "Not exist");
            collateralTokens.remove(_token);
        }
    }

    function addOrRemoveTradingToken(address _token, bool _isAdd) external onlyOwner {
        if (_isAdd) {
            require(!tradingTokens.contains(_token), "Existed");
            tradingTokens.add(_token);
        } else {
            require(tradingTokens.contains(_token), "Not exist");
            tradingTokens.remove(_token);
        }
    }

    function getCollateralTokens() external view returns (address[] memory) {
        address[] memory tokens = new address[](collateralTokens.length());

        for (uint256 i = 0; i < collateralTokens.length(); i++) {
            tokens[i] = collateralTokens.at(i);
        }

        return tokens;
    }

    function getTradingTokens() external view returns (address[] memory) {
        address[] memory tokens = new address[](tradingTokens.length());

        for (uint256 i = 0; i < tradingTokens.length(); i++) {
            tokens[i] = tradingTokens.at(i);
        }

        return tokens;
    }

    function setRefferalSystem(address _refferalSystem) external onlyOwner {
        referralSystem = IReferralSystem(_refferalSystem);
        emit SetRefferalSystem(_refferalSystem);
    }

    function initialize(
        IPriceManager _priceManager,
        ISettingsManager _settingsManager
    ) external onlyOwner {
        require(!isInitialized, "Initialized");
        require(Address.isContract(address(_priceManager)), "Invalid PriceManager");
        require(Address.isContract(address(_settingsManager)), "Invalid SettingsManager");
        priceManager = _priceManager;
        settingsManager = _settingsManager;
        isInitialized = true;
        emit Initialized(_priceManager, _settingsManager);
    }
    //End config functions

    function increasePoolAmount(address _collateralToken, uint256 _amount) public override {
        require(msg.sender == address(positionHandler), "Forbidden");
        _increasePoolAmount(_collateralToken, _amount);
    }

    function _increasePoolAmount(address _collateralToken, uint256 _amount) internal {
        if (!collateralTokens.contains(_collateralToken)) {
            collateralTokens.add(_collateralToken);
        }

        _updatePoolAmount(_collateralToken, _amount, true);
    }

    function decreasePoolAmount(address _collateralToken, uint256 _amount) public override {
        require(msg.sender == address(positionHandler), "Forbidden");
        _decreasePoolAmount(_collateralToken, _amount);
    }

    function _decreasePoolAmount(address _collateralToken, uint256 _amount) internal {
        _updatePoolAmount(_collateralToken, _amount, false);
    }

    function _updatePoolAmount(address _collateralToken, uint256 _amount, bool _isPlus) internal {
        if (_isPlus) {
            poolAmounts[_collateralToken] += _amount;
        } else {
            require(poolAmounts[_collateralToken] >= _amount, "Vault: poolAmount exceeded");
            poolAmounts[_collateralToken] -= _amount;
        }

        emit UpdatePoolAmount(_collateralToken, _amount, poolAmounts[_collateralToken], _isPlus);
    }

    function increaseReservedAmount(address _token, uint256 _amount) external override {
        _isPositionHandler(msg.sender, true);
        _updateReservedAmount(_token, _amount, true);
    }

    function decreaseReservedAmount(address _token, uint256 _amount) external override {
        _isPositionHandler(msg.sender, true);
        _updateReservedAmount(_token, _amount, false);
    }

    function _updateReservedAmount(address _token, uint256 _amount, bool _isPlus) internal {
        if (_isPlus) {
            reservedAmounts[_token] += _amount;
        } else {
            require(reservedAmounts[_token] >= _amount, "Vault: reservedAmount exceeded");
            reservedAmounts[_token] -= _amount;
        }

        emit UpdateReservedAmount(_token, _amount, reservedAmounts[_token], _isPlus);
    }

    function increaseGuaranteedAmount(address _token, uint256 _amount) external override {
        require(_isPositionHandler(msg.sender, false) || _isVaultUtils(msg.sender, false), "FBD");
        _updateGuaranteedAmount(_token, _amount, true);
    }

    function decreaseGuaranteedAmount(address _token, uint256 _amount) external override {
        require(_isPositionHandler(msg.sender, false) || _isVaultUtils(msg.sender, false), "FBD");
        _updateGuaranteedAmount(_token, _amount, false);
    }

    function _updateGuaranteedAmount(address _token, uint256 _amount, bool _isPlus) internal {
        if (_isPlus) {
            guaranteedAmounts[_token] += _amount;
        } else {
            require(guaranteedAmounts[_token] >= _amount, "Vault: guaranteedAmounts exceeded");
            guaranteedAmounts[_token] -= _amount;
        }

        emit UpdateGuaranteedAmount(_token, _amount, guaranteedAmounts[_token], _isPlus);
    }

    function takeAssetIn(
        address _account, 
        uint256 _amount, 
        address _token,
        bytes32 _key,
        uint256 _txType
    ) external override {
        require(msg.sender == positionRouter || msg.sender == address(swapRouter), "Forbidden: Not routers");
        require(_amount > 0 && _token != address(0), "Invalid amount or token");
        settingsManager.isApprovalCollateralToken(_token, true);

        if (_token == RUSD) {
            IMintable(RUSD).burn(_account, _amount);
        } else {
            _transferFrom(_token, _account, _amount);
        }

        uint256 amountInUSD = _token == RUSD ? _amount: priceManager.fromTokenToUSD(_token, _amount);
        require(amountInUSD > 0, "Invalid amountInUSD");
        bonds[_key][_txType].token = _token;
        bonds[_key][_txType].amount += _amount;
        bonds[_key][_txType].owner = _account;
        _increaseTokenBalances(_token, _amount);
        emit TakeAssetIn(_key, _txType, _account, _token, _amount, amountInUSD);
    }

    function takeAssetOut(
        bytes32 _key,
        address _account, 
        uint256 _fee, 
        uint256 _usdOut, 
        address _token, 
        uint256 _tokenPrice
    ) external override {
        _isPositionHandler(msg.sender, true);
        address refer = address(0);
        address feeManager = settingsManager.feeManager();
        uint256 rebatePercentage;
        
        if (_account != address(0) && address(referralSystem) != address(0)) {
            (refer, , rebatePercentage) = IReferralSystem(referralSystem).getDiscountable(_account);

            if (rebatePercentage >= BASIS_POINTS_DIVISOR) {
                rebatePercentage = 0;
            }
        }

        if (refer == address(0)) {
            refer = feeManager;
            rebatePercentage = BASIS_POINTS_DIVISOR;
        }

        uint256 tokenAmountOut = _takeAssetOut(
            _account, 
            refer, 
            _fee,
            rebatePercentage,
            _usdOut, 
            _token, 
            _tokenPrice,
            feeManager
        );
        emit TakeAssetOut(
            _key, 
            _account, 
            refer, 
            _usdOut, 
            _fee, 
            _token, 
            tokenAmountOut, 
            _tokenPrice
        );
    }

    function _takeAssetOut(
        address _account, 
        address _refer,
        uint256 _fee, 
        uint256 _rebatePercentage,
        uint256 _usdOut, 
        address _token, 
        uint256 _tokenPrice,
        address _feeManager
    ) internal returns (uint256) {
        require(_token != address(0) && _tokenPrice > 0, "Invalid asset");
        uint256 usdOutAfterFee = _usdOut == 0 ? 0 : _usdOut - _fee;
        //Force convert 1-1 if stable
        uint256 tokenPrice = settingsManager.isStable(_token) ? PRICE_PRECISION : _tokenPrice;
        uint256 tokenAmountOut = usdOutAfterFee == 0 ? 0 : priceManager.fromUSDToToken(_token, usdOutAfterFee, tokenPrice);
        _transferTo(_token, tokenAmountOut, _account);
        _decreaseTokenBalances(_token, tokenAmountOut);
        _collectFee(_fee, _refer, _rebatePercentage, _feeManager, false);

        return tokenAmountOut;
    }

    function takeAssetBack(
        address _account, 
        bytes32 _key,
        uint256 _txType
    ) external override {
        _isPosition();
        VaultBond memory bond = bonds[_key][_txType];

        if (bond.owner == _account && bond.amount >= 0 && bond.token != address(0)) {
            IERC20(bond.token).safeTransfer(_account, bond.amount);
            _decreaseBond(_key, _account, _txType);
            _decreaseTokenBalances(bond.token, bond.amount);
            emit TakeAssetBack(_account, bond.amount, bond.token, _key, _txType);
        }
    }

    function decreaseBond(bytes32 _key, address _account, uint256 _txType) external {
        require(msg.sender == address(positionHandler) || msg.sender == swapRouter, "Forbidden");
        _decreaseBond(_key, _account, _txType);
    }

    function _decreaseBond(bytes32 _key, address _account, uint256 _txType) internal {
        VaultBond storage bond = bonds[_key][_txType];

        if (bond.owner != address(0) && bond.owner == _account && bond.amount > 0) {
            bond.amount = 0;
            bond.token = address(0);
        }
    }

    function transferBounty(address _account, uint256 _amount) external override {
        require(_isInternal(), "FBD");

        if (_account != address(0) && _amount > 0) {
            IMintable(RUSD).mint(_account, _amount);
            emit TransferBounty(_account, _amount);
        }
    }

    function _transferFrom(address _token, address _account, uint256 _amount) internal {
        IERC20(_token).safeTransferFrom(_account, address(this), _amount);
    }

    function _transferTo(address _token, uint256 _amount, address _receiver) internal {
        if (_receiver != address(0) && _amount > 0) {
            IERC20(_token).safeTransfer(_receiver, _amount);
        }
    }

    function getROLPPrice() external view returns (uint256) {
        return _getROLPPrice();
    }

    function _getROLPPrice() internal view returns (uint256) {
        uint256 totalRolp = totalROLP();

        if (totalRolp == 0) {
            return DEFAULT_ROLP_PRICE;
        } else {
            return (BASIS_POINTS_DIVISOR * (10 ** ROLP_DECIMALS) * _getTotalUSD()) / (totalRolp * PRICE_PRECISION);
        }
    }

    function getTotalUSD() external override view returns (uint256) {
        return _getTotalUSD();
    }

    function _getTotalUSD() internal view returns (uint256) {
        uint256 aum = aumAddition;
        uint256 shortProfits;
        uint256 collateralsLength = collateralTokens.length();
        address[] memory whitelistTokens = getWhitelistTokens();

        for (uint256 i = 0; i < whitelistTokens.length; i++) {
            if (i < collateralsLength) {
                aum += poolAmounts[collateralTokens.at(i)];
            } else {
                uint256 j = i - collateralsLength;
                address indexToken = tradingTokens.at(j);
                (bool hasProfit, uint256 delta) = positionKeeper.getGlobalShortDelta(indexToken);

                if (!hasProfit) {
                    // Add losses from shorts
                    aum += delta;
                } else {
                    shortProfits += delta;
                }

                aum += guaranteedAmounts[indexToken];
                aum = aum + poolAmounts[indexToken] - reservedAmounts[indexToken];
            }
        }


        aum = shortProfits > aum ? 0 : aum - shortProfits;
        return (aumDeduction > aum ? 0 : aum - aumDeduction) + _tryGet(tokenBalances, RUSD);
    }

    function getWhitelistTokens() public view returns (address[] memory) {
        address[] memory whitelistTokens = new address[](collateralTokens.length() + tradingTokens.length());
        uint256 count = 0;

        for (uint256 i = 0; i < collateralTokens.length(); i++) {
            whitelistTokens[count] = collateralTokens.at(i);
            count++;
        }

        for (uint256 i = 0; i < tradingTokens.length(); i++) {
            whitelistTokens[count] = tradingTokens.at(i);
            count++;
        }

        return whitelistTokens;
    }

    function updateBalance(address _token) external {
        require(_isInternal() || msg.sender == owner(), "Forbidden");
        tokenBalances.set(_token, IERC20(_token).balanceOf(address(this)));
    }

    function updateBalances() external {
        require(_isInternal() || msg.sender == owner(), "Forbidden");

        for (uint256 i = 0; i < tokenBalances.length(); i++) {
            (address token, ) = tokenBalances.at(i);

            if (token != address(0) && Address.isContract(token)) {
                uint256 balance = IERC20(token).balanceOf(address(this));
                tokenBalances.set(token, balance);
            }
        }
    }

    function stake(address _account, address _token, uint256 _amount) external nonReentrant {
        require(settingsManager.isStaking(_token), "This token not allowed for staking");
        require(
            (settingsManager.checkDelegation(_account, msg.sender)) && _amount > 0,
            "Zero amount or not allowed for stakeFor"
        );
        uint256 usdAmount = priceManager.fromTokenToUSD(_token, _amount);
        _transferFrom(_token, _account, _amount);
        uint256 usdAmountFee = (usdAmount * settingsManager.stakingFee()) / BASIS_POINTS_DIVISOR;
        uint256 usdAmountAfterFee = usdAmount - usdAmountFee;
        uint256 mintAmount;
        uint256 totalRolp = totalROLP();
        uint256 totalUsd = _getTotalUSD();

        if (totalRolp == 0 || totalUsd == 0) {
            mintAmount =
                (usdAmountAfterFee * DEFAULT_ROLP_PRICE * (10 ** ROLP_DECIMALS)) /
                (PRICE_PRECISION * BASIS_POINTS_DIVISOR);
        } else {
            mintAmount = (usdAmountAfterFee * totalRolp) / totalUsd;
        }

        _collectFee(usdAmountFee, ZERO_ADDRESS, 0, address(0), true);
        require(mintAmount > 0, "Staking amount too low");
        IMintable(ROLP).mint(_account, mintAmount);
        lastStakedAt[_account] = block.timestamp;
        _increaseTokenBalances(_token, _amount);
        _increasePoolAmount(_token, usdAmountAfterFee);
        stakeAmounts[_token] += usdAmountAfterFee;
        emit Stake(_account, _token, _amount, mintAmount);
    }

    function unstake(address _tokenOut, uint256 _rolpAmount, address _receiver) external nonReentrant {
        require(settingsManager.isApprovalCollateralToken(_tokenOut), "Invalid approvalToken");
        uint256 totalRolp = totalROLP();
        require(_rolpAmount > 0 && totalRolp > 0 && _rolpAmount <= totalRolp, "Zero amount not allowed and cant exceed total ROLP");
        require(
            lastStakedAt[msg.sender] + settingsManager.cooldownDuration() <= block.timestamp,
            "Cooldown duration not yet passed"
        );
        require(settingsManager.isEnableUnstaking(), "Not enable unstaking");

        IMintable(ROLP).burn(msg.sender, _rolpAmount);
        uint256 usdAmount = (_rolpAmount * _getTotalUSD()) / totalRolp;
        uint256 usdAmountFee = (usdAmount * settingsManager.unstakingFee()) / BASIS_POINTS_DIVISOR;
        uint256 usdAmountAfterFee = usdAmount - usdAmountFee;
        uint256 amountOutInToken = usdAmountAfterFee == 0 ? 0 
            : (_tokenOut == RUSD ? usdAmountAfterFee: priceManager.fromUSDToToken(_tokenOut, usdAmountAfterFee));
        require(amountOutInToken > 0, "Unstaking amount too low");

        _decreaseTokenBalances(_tokenOut, amountOutInToken);
        _decreasePoolAmount(_tokenOut, usdAmountAfterFee);
        _collectFee(usdAmountFee, ZERO_ADDRESS, 0, address(0), true);
        require(IERC20(_tokenOut).balanceOf(address(this)) >= amountOutInToken, "Insufficient");
        _transferTo(_tokenOut, amountOutInToken, _receiver);
        stakeAmounts[_tokenOut] -= usdAmountAfterFee;
        emit Unstake(msg.sender, _tokenOut, _rolpAmount, amountOutInToken);
    }

    function totalROLP() public view returns (uint256) {
        return IERC20(ROLP).totalSupply();
    }

    function totalRUSD() public view returns (uint256) {
        return IERC20(RUSD).totalSupply();
    }

    function distributeFee(bytes32 _key, address _account, uint256 _fee) external override {
        _isPositionHandler(msg.sender, true);
        address feeManager = settingsManager.feeManager();
        _collectFee(_fee, address(0), 0, feeManager, false);

        if (_fee > 0) {
            emit DistributeFee(_key, _account, feeManager, _fee);
        }
    }

    function _collectFee(uint256 _fee, address _refer, uint256 _rebatePercentage, address _feeManager, bool _isStake) internal {
        if (_feeManager == address(0)) {
            _feeManager = settingsManager.feeManager();
        }
        
        //Pay rebate first
        if (_refer != ZERO_ADDRESS && settingsManager.referEnabled()) {
            uint256 referFee = (_fee * _rebatePercentage) / BASIS_POINTS_DIVISOR;
            _fee -= referFee;

            if (referFee > 0) {
                IMintable(RUSD).mint(_refer, referFee);
            }
        }

        if (_fee > 0 && _feeManager != ZERO_ADDRESS) {
            //Stake/Unstake will take full fee, otherwise reserve to vault
            uint256 feeReserve = _isStake ? 0 : ((_fee * settingsManager.feeRewardBasisPoints()) / BASIS_POINTS_DIVISOR);
            uint256 systemFee = _fee - feeReserve;
            _fee -= systemFee;

            if (systemFee > 0) {
                IMintable(RUSD).mint(_feeManager, systemFee);
            }
        }

        if (_fee > 0) {
            //Reserve fee for vault
            IMintable(RUSD).mint(address(this), _fee);
            _increaseTokenBalances(RUSD, _fee);
        }
    }

    function rescueERC20(address _recipient, address _token, uint256 _amount) external onlyOwner {
        bool isVaultBalance = tokenBalances.get(_token) > 0;
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Insufficient");
        IERC20(_token).safeTransfer(_recipient, _amount);

        if (isVaultBalance) {
            _decreaseTokenBalances(_token, _amount);
        }

        emit RescueERC20(_recipient, _token, _amount);
    }

    function convertRUSD(
        address _account,
        address _recipient, 
        address _tokenOut, 
        uint256 _amount
    ) external nonReentrant {
        require(msg.sender == _account || msg.sender == converter, "Forbidden");
        settingsManager.isApprovalCollateralToken(_tokenOut, true);
        require(settingsManager.isEnableConvertRUSD(), "Convert RUSD temporarily disabled");
        require(_amount > 0 && IERC20(RUSD).balanceOf(_account) >= _amount, "Insufficient RUSD to convert");
        IMintable(RUSD).burn(_account, _amount);
        uint256 amountOut = settingsManager.isStable(_tokenOut) ? priceManager.fromUSDToToken(_tokenOut, _amount, PRICE_PRECISION) 
                : priceManager.fromUSDToToken(_tokenOut, _amount);
        require(IERC20(_tokenOut).balanceOf(address(this)) >= amountOut, "Insufficient");
        IERC20(_tokenOut).safeTransfer(_recipient, amountOut);
        _decreaseTokenBalances(_tokenOut, amountOut);
        emit ConvertRUSD(_recipient, _tokenOut, _amount, amountOut);
    }

    function directDeposit(address _token, uint256 _amount) external {
        settingsManager.isApprovalCollateralToken(_token, true);
        require(_amount > 0, "ZERO amount");
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 amountInUSD = priceManager.fromTokenToUSD(_token, _amount);
        _increaseTokenBalances(_token, _amount);
        _updatePoolAmount(_token, amountInUSD, true);
    }

    function getTokenBalances() external view returns (address[] memory, uint256[] memory) {
        return _iterator();
    }

    function getTokenBalance(address _token) external view returns (uint256) {
        return tokenBalances.get(_token);
    }

    function _iterator() internal view returns (address[] memory, uint256[] memory) {
        address[] memory tokensArr = new address[](tokenBalances.length());
        uint256[] memory balancesArr = new uint256[](tokenBalances.length());

        for (uint256 i = 0; i < tokenBalances.length(); i++) {
            (address token, uint256 balance) = tokenBalances.at(i);
            tokensArr[i] = token;
            balancesArr[i] = balance;
        }

        return (tokensArr, balancesArr);
    }

    function _increaseTokenBalances(address _token, uint256 _amount) internal {
        _setBalance(_token, _amount, true);
    }

    function _decreaseTokenBalances(address _token, uint256 _amount) internal {
        _setBalance(_token, _amount, false);
    }

    function _setBalance(address _token, uint256 _amount, bool _isPlus) internal {
        if (_amount > 0) {
            uint256 prevBalance = _tryGet(tokenBalances, _token);

            if (!_isPlus && prevBalance < _amount) {
                revert("Vault balances exceeded");
            } 
            
            uint256 newBalance = _isPlus ? prevBalance + _amount : prevBalance - _amount;
            tokenBalances.set(_token, newBalance);
        }
    }

    function _tryGet(EnumerableMap.AddressToUintMap storage _map, address _key) internal view returns (uint256) {
        (, uint256 val) = _map.tryGet(_key);
        return val;
    }

    function _isInternal() internal view returns (bool) {
        return _isPosition() || _isSwapRouter(msg.sender, false);
    }

    function _isPosition() internal view returns (bool) {
        return _isPositionHandler(msg.sender, false) 
            || _isPositionRouter(msg.sender, false);
    }

    function _isPositionRouter(address _caller, bool _raise) internal view returns (bool) {
        bool res = _caller == address(positionRouter);

        if (_raise && !res) {
            revert("Forbidden: Not positionRouter");
        }

        return res;
    }

    function _isPositionHandler(address _caller, bool _raise) internal view returns (bool) {
        bool res = _caller == address(positionHandler);

        if (_raise && !res) {
            revert("Forbidden: Not positionHandler");
        }

        return res;
    }

    function _isSwapRouter(address _caller, bool _raise) internal view returns (bool) {
        bool res = _caller == address(swapRouter);

        if (_raise && !res) {
            revert("Forbidden: Not swapRouter");
        }

        return res;
    }

    function _isVaultUtils(address _caller, bool _raise) internal view returns (bool) {
        bool res = _caller == vaultUtils;

        if (_raise && !res) {
            revert("Forbidden: Not vaultUtils");
        }

        return res;
    }

    //This function is using for re-intialized settings
    function reInitializedForDev(bool _isInitialized) external onlyOwner {
       isInitialized = _isInitialized;
    }

    function getBond(bytes32 _key, uint256 _txType) external override view returns (VaultBond memory) {
        return bonds[_key][_txType];
    }

    function getBondOwner(bytes32 _key, uint256 _txType) external override view returns (address) {
        return bonds[_key][_txType].owner;
    }

    function getBondToken(bytes32 _key, uint256 _txType) external override view returns (address) {
        return bonds[_key][_txType].token;
    }

    function getBondAmount(bytes32 _key, uint256 _txType) external override view returns (uint256) {
        return bonds[_key][_txType].amount;
    }
}