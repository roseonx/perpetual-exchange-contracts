// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "./IMintable.sol";
import "./IBurnable.sol";

interface ITokenModifiable is IMintable, IBurnable {
    function setMinter(address _minter) external;

    function revokeMinter(address _minter) external;

    function isMinter(address _account) external returns (bool);
}