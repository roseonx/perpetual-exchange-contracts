// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../tokens/interfaces/IBurnable.sol";
import "../tokens/interfaces/ILockROSX.sol";
import "../core/interfaces/IBlacklistManager.sol";

contract VestEROSXV2 is OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeMathUpgradeable for uint256;

    event Deposit(address indexed account, uint256 amount);
    event Claim(address indexed receiver, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);
    event SetWhitelist(address indexed account, bool isWhitelist);

    uint256 public vestingDuration;
    address public esToken;
    address public lockRosx;
    address public claimableToken;

    /*** DATA TYPES ***/
    struct VestingData {
        uint256 amountStake;
        uint256 amountClaimed;
        uint256 amountDebt;
        uint256 lastVestingTime;
    }

    mapping(address => VestingData) public vesting;
    mapping(address => bool) public whitelist;
    address public blacklistManager;
    uint256[48] private __gap;

    function initialize(address _claimableToken, address _esToken) public initializer {
        require(address(_claimableToken) != address(0), "zeroAddr");
        require(address(_esToken) != address(0), "zeroAddr");
        claimableToken = _claimableToken;
        esToken = _esToken;
        __Ownable_init();
        _initVestingDuration();
    }

    function _initVestingDuration() internal {
        if (vestingDuration == 0) {
            vestingDuration = 180 days;
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {
        
    }

    function deposit(uint256 _amount) external nonReentrant {
        _validateBlacklist(msg.sender);
        require(_amount > 0, "Amount Invalid");
        bool isSuccessLock = ILockROSX(lockRosx).lock(msg.sender, _amount);

        if (!whitelist[msg.sender]) {
            require(isSuccessLock, "Not Token Reserve");
        }

        require(IERC20Upgradeable(esToken).transferFrom(msg.sender, address(this), _amount), "TransferFrom Fail");
        _updateVesting(msg.sender);
        vesting[msg.sender].amountStake = vesting[msg.sender].amountStake.add(_amount);
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        _validateBlacklist(msg.sender);
        require(_amount > 0, "Amount Invalid");
        _updateVesting(msg.sender);
        VestingData storage userVesting = vesting[msg.sender];

        require(_amount <= userVesting.amountStake, "Amount Invalid");
        bool isSuccessUnlock = ILockROSX(lockRosx).unLock(msg.sender, _amount);

        if (!whitelist[msg.sender]) {
            require(isSuccessUnlock, "Not Token Reserve");
        }

        require(IERC20Upgradeable(esToken).transfer(msg.sender, _amount), "Transfer Fail");
        userVesting.amountStake = userVesting.amountStake.sub(_amount);
        emit Withdraw(msg.sender, _amount);
    }

    function claim() external nonReentrant returns (uint256) {
        _validateBlacklist(msg.sender);
        _updateVesting(msg.sender);
        VestingData storage userVesting = vesting[msg.sender];
        require(IERC20Upgradeable(claimableToken).transfer(msg.sender, userVesting.amountDebt), "Transfer Fail");
        uint256 amount = userVesting.amountDebt;
        userVesting.amountClaimed = userVesting.amountClaimed.add(amount);
        userVesting.amountDebt = 0;
        emit Claim(msg.sender, amount);
        return amount;
    }

    function claimable(address _account) public view returns (uint256) {
        VestingData memory userVesting = vesting[_account];
        uint256 nextClaimable = _getNextClaimableAmount(_account);
        return userVesting.amountDebt.add(nextClaimable);
    }

    function _updateVesting(address _account) private {
        uint256 amount = _getNextClaimableAmount(_account);
        VestingData storage userVesting = vesting[_account];
        userVesting.lastVestingTime = block.timestamp;

        if (amount == 0) {
            return;
        }
    
        userVesting.amountStake = userVesting.amountStake.sub(amount);
        userVesting.amountDebt = userVesting.amountDebt.add(amount);
        bool isSuccessUnlock = ILockROSX(lockRosx).unLock(msg.sender, amount);

        if (!whitelist[msg.sender]) {
            require(isSuccessUnlock, "Not Token Reserve");
        }

        IBurnable(esToken).burn(address(this), amount);
    }

    function _getNextClaimableAmount(address _account) private view returns (uint256) {
        VestingData memory userVesting = vesting[_account];

        if (userVesting.amountStake == 0) {
            return 0;
        }

        uint256 timeDiff = block.timestamp.sub(userVesting.lastVestingTime);
        uint256 vestedAmount = userVesting.amountStake;
        uint256 claimableAmount = vestedAmount.mul(timeDiff).div(vestingDuration);

        if (claimableAmount < vestedAmount) {
            return claimableAmount;
        }

        return vestedAmount;
    }
    
    /**
     * @notice withdrawn token to owner
     */
    function withdrawBalance(address _token, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).transfer(owner(), _amount);
    }

    function setLockRosxAddress(address _lockRosx) external onlyOwner {
        lockRosx = _lockRosx;
    }

    //To help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).transfer(_account, _amount);
    }

    function setVestingDuration(uint256 _vestingDuration) external onlyOwner {
        vestingDuration = _vestingDuration;
    }

    //Old logic
    function setWhitelist(address _account, bool _isWhitelist) external onlyOwner {
        whitelist[_account] = _isWhitelist;
        emit SetWhitelist(_account, _isWhitelist);
    }

    function setBlacklistManager(address _blacklistManager) external onlyOwner {
        blacklistManager = _blacklistManager;
    }

    //New logic
    function _validateBlacklist(address _account) internal view {
        IBlacklistManager(blacklistManager).validateCaller(_account);
    }

    //Let updater fix vesting in case of emergency
    function updateVestingDebt(address _account, uint256 _amount, bool _isPlus) external onlyOwner {
        VestingData storage vest = vesting[_account];
        uint256 maxAmount = vest.amountStake + vest.amountDebt + vest.amountClaimed;
        require(_amount <= maxAmount, "Amount exceeded");

        if (_isPlus) {
            require(_amount <= vest.amountStake, "Insufficient");
            vest.amountDebt += _amount;
            vest.amountStake -= _amount;
        } else {
            require(_amount <= vest.amountDebt, "Insufficient");
            vest.amountDebt -= _amount;
            vest.amountStake += _amount;
        }
    }
}
