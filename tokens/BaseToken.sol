// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BaseToken is ERC20Burnable, Pausable, Ownable {
    using SafeERC20 for IERC20;
    
    event RescueToken(address indexed caller, address indexed indexToken, address indexed recipient, uint256 amount);

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) ERC20(_name, _symbol) {
        if (_initialSupply > 0) {
            _mint(msg.sender, _initialSupply);
        }
    }

    function rescueToken(address _token, address _account, uint256 _amount) external onlyOwner {
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Insufficient");
        IERC20(_token).safeTransfer(_account, _amount);
        emit RescueToken(msg.sender, _token, _account, _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}

