// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestERC20 is ERC20Burnable, Ownable {
    string public tokenSymbol;
    uint8 public tokenDecimals;
    bool public isTest;

    constructor(string memory _symbol, uint8 _decimals) ERC20(_symbol, _symbol) {
        tokenDecimals = _decimals;
        tokenSymbol = _symbol;
        _mint(msg.sender, 1_000_000_000 * 10**_decimals);
    }

    function setTest(bool _isTest) external onlyOwner {
        isTest = _isTest;
    }

    function mint(uint256 amount) external {
        if (!isTest) {
            require(msg.sender == owner(), "Invalid owner");
        }

        _mint(msg.sender, amount);
    }

    function withdrawToken(address token, address recipient, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this)) >= 0, "Insufficient");
        IERC20(token).transfer(recipient, amount);
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }

    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    function name() public view override returns (string memory) {
        return tokenSymbol;
    }
}