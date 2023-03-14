// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./MintableBaseToken.sol";

contract esROSX is MintableBaseToken {
    constructor() MintableBaseToken("Escrowed ROSX", "esROSX", 0) {}

    function id() external pure returns (string memory _name) {
        return "esROSX";
    }
}
