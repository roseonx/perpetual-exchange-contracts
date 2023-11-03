// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IRewardDistributorV2.sol";
import "./interfaces/IRewardTrackerV2.sol";

contract RewardDistributorV2 is IRewardDistributorV2, ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public override rewardToken;
    uint256 public override tokensPerInterval;
    uint256 public lastDistributionTime;
    address public rewardTracker;

    address public admin;
    uint256[50] private __gap;

    event Distribute(uint256 amount);
    event TokensPerIntervalChange(uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "RewardDistributor: forbidden");
        _;
    }

    function initialize(address _rewardToken, address _rewardTracker) public initializer {
        __Ownable_init();
        rewardToken = _rewardToken;
        rewardTracker = _rewardTracker;
        admin = msg.sender;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {
        
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(_account, _amount);
    }

    function updateLastDistributionTime() external onlyAdmin {
        lastDistributionTime = block.timestamp;
    }

    function setTokensPerInterval(uint256 _amount) external onlyAdmin {
        require(lastDistributionTime != 0, "RewardDistributor: invalid lastDistributionTime");
        IRewardTrackerV2(rewardTracker).updateRewards();
        tokensPerInterval = _amount;
        emit TokensPerIntervalChange(_amount);
    }

    function pendingRewards() public view override returns (uint256) {
        if (block.timestamp == lastDistributionTime) {
            return 0;
        }

        uint256 timeDiff = block.timestamp - lastDistributionTime;
        return tokensPerInterval * timeDiff;
    }

    function distribute() external override returns (uint256) {
        require(msg.sender == rewardTracker, "RewardDistributor: invalid msg.sender");
        uint256 amount = pendingRewards();
        if (amount == 0) { return 0; }

        lastDistributionTime = block.timestamp;

        uint256 balance = IERC20Upgradeable(rewardToken).balanceOf(address(this));
        if (amount > balance) { amount = balance; }

        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, amount);

        emit Distribute(amount);
        return amount;
    }
}