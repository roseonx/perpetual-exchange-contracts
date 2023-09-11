// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

/**
 * @dev Interface of the VeDxp
 */
interface ITokenFarmV2 {
    function getTier(uint256 _pid, address _account) external view returns (uint256);
}