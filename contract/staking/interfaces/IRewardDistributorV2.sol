// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IRewardDistributorV2 {
    function rewardToken() external view returns (address);
    function tokensPerInterval() external view returns (uint256);
    function pendingRewards() external view returns (uint256);
    function distribute() external returns (uint256);
}