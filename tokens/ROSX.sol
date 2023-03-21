// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "./MintableBaseToken.sol";

contract ROSX is ERC20Capped, MintableBaseToken {
    uint256 public immutable MAX_SUPPLY = 200_000_000 * 10**18;

    constructor() ERC20Capped(200_000_000 * 10**18) MintableBaseToken("Roseon", "ROSX", 0) {
        
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(BaseToken, ERC20) whenNotPaused {
        BaseToken._beforeTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        ERC20Capped._mint(account, amount);
    }
}

