// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "./MintableBaseTokenV2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract sROLP is MintableBaseTokenV2, UUPSUpgradeable {
    uint256[50] private __gap;

    function initialize() public initializer {
        _initialize("Staked ROLP", "sROLP", 0);
    }


    function _authorizeUpgrade(address) internal override onlyOwner {
        
    }
}
