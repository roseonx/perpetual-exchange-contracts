// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "./MintableBaseToken.sol";

contract ROSX is MintableBaseToken {
    uint256 public currentSupply;

    uint256 public maxSupply = 200_000_000 * 10**18;

    constructor() MintableBaseToken("Roseon", "ROSX", 0) {
        
    }

    function mint(address _account, uint256 _amount) external onlyOwner override {
        if (currentSupply + _amount > maxSupply) {
            revert("Max supply exceeded");
        } else {
            currentSupply += _amount;
            _mint(_account, _amount);
        }
    }

    function totalSupply() public view virtual override returns (uint256) {
        return currentSupply;
    }

    function _burn(address _account, uint256 _amount) internal virtual override {
        currentSupply -= _amount;
        super._burn(_account, _amount);
    }
}
