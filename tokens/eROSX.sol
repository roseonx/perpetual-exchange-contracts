// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./MintableBaseToken.sol";

contract eROSX is MintableBaseToken {
    constructor() MintableBaseToken("Escrowed ROSX", "eROSX", 0) {}

    function id() external pure returns (string memory _name) {
        return "eROSX";
    }
}
