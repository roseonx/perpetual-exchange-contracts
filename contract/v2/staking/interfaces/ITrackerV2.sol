// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface ITrackerV2 {
    function burn(address _addr, uint256 _amount) external ;
    function mint(address _addr, uint256 _amount) external ;
}
