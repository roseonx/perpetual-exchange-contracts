// SPDX-License-Identifier: AGPL

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StakedTracker is ERC20, ERC20Burnable, Ownable, Pausable {
    
    mapping(address => bool) public  isMinter;

    modifier onlyMinter() {
        require(isMinter[msg.sender], "MintableBaseToken: forbidden");
        _;
    }

    bool public inPrivateTransferMode = true;


    constructor( string memory _name,
        string memory _symbol) ERC20(_name, _symbol) {
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