// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IRewardTracker.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
//import "../core/interfaces/IROLPManager.sol";

contract RewardRouter is ReentrancyGuard, Ownable {
    // using SafeERC20 for IERC20;
    // using Address for address payable;

    // bool public isInitialized;

    // address public weth;

    // address public gmx;
    // address public esGmx;
    // address public bnGmx;

    // address public glp; // GMX Liquidity Provider token

    // address public stakedGmxTracker;
    // address public bonusGmxTracker;
    // address public feeGmxTracker;

    // address public stakedGlpTracker;
    // address public feeGlpTracker;

    // address public rolpManager;

    // event StakeGmx(address account, uint256 amount);
    // event UnstakeGmx(address account, uint256 amount);

    // event StakeGlp(address account, uint256 amount);
    // event UnstakeGlp(address account, uint256 amount);

    // receive() external payable {
    //     require(msg.sender == weth, "Router: invalid sender");
    // }

    // constructor() {
    //     _transferOwnership(msg.sender);
    // }

    // function initialize(
    //     address _weth,
    //     address _gmx,
    //     address _esGmx,
    //     address _bnGmx,
    //     address _glp,
    //     address _stakedGmxTracker,
    //     address _bonusGmxTracker,
    //     address _feeGmxTracker,
    //     address _feeGlpTracker,
    //     address _stakedGlpTracker,
    //     address _glpManager
    // ) external onlyOwner {
    //     require(!isInitialized, "RewardRouter: Already initialized");
    //     isInitialized = true;

    //     weth = _weth;

    //     gmx = _gmx;
    //     esGmx = _esGmx;
    //     bnGmx = _bnGmx;

    //     glp = _glp;

    //     stakedGmxTracker = _stakedGmxTracker;
    //     bonusGmxTracker = _bonusGmxTracker;
    //     feeGmxTracker = _feeGmxTracker;

    //     feeGlpTracker = _feeGlpTracker;
    //     stakedGlpTracker = _stakedGlpTracker;

    //     rolpManager = _glpManager;
    // }

    // // to help users who accidentally send their tokens to this contract
    // function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
    //     IERC20(_token).safeTransfer(_account, _amount);
    // }

    // function batchStakeGmxForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyOwner {
    //     address _gmx = gmx;
    //     for (uint256 i = 0; i < _accounts.length; i++) {
    //         _stakeGmx(msg.sender, _accounts[i], _gmx, _amounts[i]);
    //     }
    // }

    // function stakeGmxForAccount(address _account, uint256 _amount) external nonReentrant onlyOwner {
    //     _stakeGmx(msg.sender, _account, gmx, _amount);
    // }

    // function stakeGmx(uint256 _amount) external nonReentrant {
    //     _stakeGmx(msg.sender, msg.sender, gmx, _amount);
    // }

    // function stakeEsGmx(uint256 _amount) external nonReentrant {
    //     _stakeGmx(msg.sender, msg.sender, esGmx, _amount);
    // }

    // function unstakeGmx(uint256 _amount) external nonReentrant {
    //     _unstakeGmx(msg.sender, gmx, _amount);
    // }

    // function unstakeEsGmx(uint256 _amount) external nonReentrant {
    //     _unstakeGmx(msg.sender, esGmx, _amount);
    // }

    // function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp) external nonReentrant returns (uint256) {
    //     require(_amount > 0, "RewardRouter: invalid _amount");

    //     address account = msg.sender;
    //     uint256 rolpAmount = IROLPManager(rolpManager).addLiquidityForAccount(account, account, _token, _amount, _minUsdg, _minGlp);
    //     IRewardTracker(feeGlpTracker).stakeForAccount(account, account, glp, rolpAmount);
    //     IRewardTracker(stakedGlpTracker).stakeForAccount(account, account, feeGlpTracker, rolpAmount);

    //     emit StakeGlp(account, rolpAmount);

    //     return rolpAmount;
    // }

    // function mintAndStakeGlpETH(uint256 _minUsdg, uint256 _minGlp) external payable nonReentrant returns (uint256) {
    //     require(msg.value > 0, "RewardRouter: invalid msg.value");

    //     IWETH(weth).deposit{value: msg.value}();
    //     IERC20(weth).approve(rolpManager, msg.value);

    //     address account = msg.sender;
    //     uint256 rolpAmount = IROLPManager(rolpManager).addLiquidityForAccount(address(this), account, weth, msg.value, _minUsdg, _minGlp);

    //     IRewardTracker(feeGlpTracker).stakeForAccount(account, account, glp, rolpAmount);
    //     IRewardTracker(stakedGlpTracker).stakeForAccount(account, account, feeGlpTracker, rolpAmount);

    //     emit StakeGlp(account, rolpAmount);

    //     return rolpAmount;
    // }

    // function unstakeAndRedeemGlp(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver) external nonReentrant returns (uint256) {
    //     require(_glpAmount > 0, "RewardRouter: invalid _glpAmount");

    //     address account = msg.sender;
    //     IRewardTracker(stakedGlpTracker).unstakeForAccount(account, feeGlpTracker, _glpAmount, account);
    //     IRewardTracker(feeGlpTracker).unstakeForAccount(account, glp, _glpAmount, account);
    //     uint256 amountOut = IROLPManager(rolpManager).removeLiquidityForAccount(account, _tokenOut, _glpAmount, _minOut, _receiver);

    //     emit UnstakeGlp(account, _glpAmount);

    //     return amountOut;
    // }

    // function unstakeAndRedeemGlpETH(uint256 _glpAmount, uint256 _minOut, address payable _receiver) external nonReentrant returns (uint256) {
    //     require(_glpAmount > 0, "RewardRouter: invalid _glpAmount");

    //     address account = msg.sender;
    //     IRewardTracker(stakedGlpTracker).unstakeForAccount(account, feeGlpTracker, _glpAmount, account);
    //     IRewardTracker(feeGlpTracker).unstakeForAccount(account, glp, _glpAmount, account);
    //     uint256 amountOut = IROLPManager(rolpManager).removeLiquidityForAccount(account, weth, _glpAmount, _minOut, address(this));

    //     IWETH(weth).withdraw(amountOut);

    //     _receiver.sendValue(amountOut);

    //     emit UnstakeGlp(account, _glpAmount);

    //     return amountOut;
    // }

    // function claim() external nonReentrant {
    //     address account = msg.sender;

    //     IRewardTracker(feeGmxTracker).claimForAccount(account, account);
    //     IRewardTracker(feeGlpTracker).claimForAccount(account, account);

    //     IRewardTracker(stakedGmxTracker).claimForAccount(account, account);
    //     IRewardTracker(stakedGlpTracker).claimForAccount(account, account);
    // }

    // function claimEsGmx() external nonReentrant {
    //     address account = msg.sender;

    //     IRewardTracker(stakedGmxTracker).claimForAccount(account, account);
    //     IRewardTracker(stakedGlpTracker).claimForAccount(account, account);
    // }

    // function claimFees() external nonReentrant {
    //     address account = msg.sender;

    //     IRewardTracker(feeGmxTracker).claimForAccount(account, account);
    //     IRewardTracker(feeGlpTracker).claimForAccount(account, account);
    // }

    // function compound() external nonReentrant {
    //     _compound(msg.sender);
    // }

    // function compoundForAccount(address _account) external nonReentrant onlyOwner {
    //     _compound(_account);
    // }

    // function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyOwner {
    //     for (uint256 i = 0; i < _accounts.length; i++) {
    //         _compound(_accounts[i]);
    //     }
    // }

    // function _compound(address _account) private {
    //     _compoundGmx(_account);
    //     _compoundGlp(_account);
    // }

    // function _compoundGmx(address _account) private {
    //     uint256 esGmxAmount = IRewardTracker(stakedGmxTracker).claimForAccount(_account, _account);
    //     if (esGmxAmount > 0) {
    //         _stakeGmx(_account, _account, esGmx, esGmxAmount);
    //     }

    //     uint256 bnGmxAmount = IRewardTracker(bonusGmxTracker).claimForAccount(_account, _account);
    //     if (bnGmxAmount > 0) {
    //         IRewardTracker(feeGmxTracker).stakeForAccount(_account, _account, bnGmx, bnGmxAmount);
    //     }
    // }

    // function _compoundGlp(address _account) private {
    //     uint256 esGmxAmount = IRewardTracker(stakedGlpTracker).claimForAccount(_account, _account);
    //     if (esGmxAmount > 0) {
    //         _stakeGmx(_account, _account, esGmx, esGmxAmount);
    //     }
    // }

    // function _stakeGmx(address _fundingAccount, address _account, address _token, uint256 _amount) private {
    //     require(_amount > 0, "RewardRouter: invalid _amount");

    //     IRewardTracker(stakedGmxTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
    //     IRewardTracker(bonusGmxTracker).stakeForAccount(_account, _account, stakedGmxTracker, _amount);
    //     IRewardTracker(feeGmxTracker).stakeForAccount(_account, _account, bonusGmxTracker, _amount);

    //     emit StakeGmx(_account, _amount);
    // }

    // function _unstakeGmx(address _account, address _token, uint256 _amount) private {
    //     require(_amount > 0, "RewardRouter: invalid _amount");

    //     uint256 balance = IRewardTracker(stakedGmxTracker).stakedAmounts(_account);

    //     IRewardTracker(feeGmxTracker).unstakeForAccount(_account, bonusGmxTracker, _amount, _account);
    //     IRewardTracker(bonusGmxTracker).unstakeForAccount(_account, stakedGmxTracker, _amount, _account);
    //     IRewardTracker(stakedGmxTracker).unstakeForAccount(_account, _token, _amount, _account);

    //     uint256 bnGmxAmount = IRewardTracker(bonusGmxTracker).claimForAccount(_account, _account);
    //     if (bnGmxAmount > 0) {
    //         IRewardTracker(feeGmxTracker).stakeForAccount(_account, _account, bnGmx, bnGmxAmount);
    //     }

    //     uint256 stakedBnGmx = IRewardTracker(feeGmxTracker).depositBalances(_account, bnGmx);
    //     if (stakedBnGmx > 0) {
    //         uint256 reductionAmount = stakedBnGmx * _amount / balance;
    //         IRewardTracker(feeGmxTracker).unstakeForAccount(_account, bnGmx, reductionAmount, _account);
    //         IMintable(bnGmx).burn(_account, reductionAmount);
    //     }

    //     emit UnstakeGmx(_account, _amount);
    // }
}