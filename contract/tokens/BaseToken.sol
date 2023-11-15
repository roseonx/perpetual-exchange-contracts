// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract BaseToken is Initializable, OwnableUpgradeable, PausableUpgradeable, ERC20BurnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    uint256[50] private __gap;
    
    event RescueToken(address indexed caller, address indexed indexToken, address indexed recipient, uint256 amount);

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) internal virtual {
        __Ownable_init();
        __ERC20_init(_name, _symbol);

        if (_initialSupply > 0) {
            _mint(msg.sender, _initialSupply);
        }
    }

    function rescueToken(address _token, address _account, uint256 _amount) external onlyOwner {
        require(IERC20Upgradeable(_token).balanceOf(address(this)) >= _amount, "Insufficient");
        IERC20Upgradeable(_token).safeTransfer(_account, _amount);
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