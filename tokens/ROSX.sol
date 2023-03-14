// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./MintableBaseToken.sol";

contract Rosx is MintableBaseToken {

    constructor() public MintableBaseToken("ROSX", "ROSX", 0) {
    }


}
