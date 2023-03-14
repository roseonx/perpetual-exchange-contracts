// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IClaimable {
    function setClaimable(address _account, uint256 _amount) external;

    function getClaimable(address _account) external view returns (uint256);

    function claim() external returns (uint256);
}
