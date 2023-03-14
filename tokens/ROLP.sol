// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./MintableBaseToken.sol";

contract ROLP is MintableBaseToken {
    constructor() MintableBaseToken("ROSX LP", "ROLP", 0) {}

    function id() external pure returns (string memory _name) {
        return "ROLP";
    }
}
