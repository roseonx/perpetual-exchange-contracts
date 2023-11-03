// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "./AbstractTokenModifiable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract sROSX is AbstractTokenModifiable, UUPSUpgradeable {
    uint256[50] private __gap;

    function initialize() public initializer {
        _initialize("Staked ROSX", "sROSX", 0);
    }


    function _authorizeUpgrade(address) internal override onlyOwner {
        
    }
}
