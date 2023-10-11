// SPDX-License-Identifier: AGPL

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract StakedTrackerV2 is ERC20BurnableUpgradeable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    mapping(address => bool) public isMinter;
    bool public inPrivateTransferMode;
    uint256[50] private __gap;

    modifier onlyMinter() {
        require(isMinter[msg.sender], "MintableBaseToken: forbidden");
        _;
    }

    function initialize(
        string memory _name,
        string memory _symbol
    ) public initializer {
        __Ownable_init();
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        inPrivateTransferMode = true;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {
        
    }

    function burn(address _account, uint256 _amount) external onlyMinter {
        _burn(_account, _amount);
    }

    function mint(address _account, uint256 _amount) external onlyMinter {
        _mint(_account, _amount);
    }

    function setMinter(address _minter, bool _isActive) external  onlyOwner {
        isMinter[_minter] = _isActive;
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyOwner {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    function _validateHandler() private view {
        require(isMinter[msg.sender], "RewardTracker: forbidden");
    }

    /**
     * @notice  Permissioned pause to owner
     */
    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @notice  Permissioned unpause to owner
     */
    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal whenNotPaused override {
        if (inPrivateTransferMode) { _validateHandler(); }
        super._beforeTokenTransfer(_from, _to, _amount);
    } 
}