// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "./interfaces/IClaimable.sol";
import "./MintableBaseToken.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AirdropToken is IClaimable, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;

    mapping(address => uint256) public claimable;

    uint256 public totalClaimed;

    uint256 public maxClaimed;

    mapping(address => uint256) public claimedAmounts;

    event Claim(address receiver, uint256 amount);
    

    constructor(address _token, uint256 _maxClaimed)  {
        require(Address.isContract(_token), "Token is not contract");
        token = IERC20(_token);
        maxClaimed = _maxClaimed;
    }

    function getName() external view returns(string memory) {
        return IERC20Metadata(address(token)).name();
    }

    function getSymbol() external view returns(string memory) {
        return IERC20Metadata(address(token)).symbol();
    }

    function setClaimable(address _account, uint256 _amount) external override onlyOwner {
        require(_account != address(0), "AirdropToken: claim to the zero address");
        require(!Address.isContract(_account), "Account must not be contract");
        claimable[_account] += _amount;
    }

    function getClaimable(address _account) external view returns (uint256){
        return claimable[_account];
    }

    function claim() external nonReentrant returns (uint256) {
        require(!Address.isContract(_msgSender()), "Caller must not be contract");
        require(claimable[_msgSender()] > 0, "Nothing to claim");
        return _claim(_msgSender(), claimable[_msgSender()]);
    }

    function _claim(address _account, uint256 _tokenAmount) internal whenNotPaused returns (uint256)  {
        if (_tokenAmount > 0) {
            claimable[_account] = 0;
            totalClaimed += _tokenAmount;
            require(token.balanceOf(address(this)) >= _tokenAmount, "Available exceeded");
            require(totalClaimed <= maxClaimed, "Max claim exceeded");
            claimedAmounts[_account] += _tokenAmount;
            IERC20(token).safeTransfer(_account, _tokenAmount);
            emit Claim(_account, _tokenAmount);
        }

        return _tokenAmount;
    }

    function batchClaims(address[] calldata _accounts, uint256[] calldata _amounts) external onlyOwner {
        require(_accounts.length == _amounts.length, "Address length must be same");
        require(_accounts.length > 0, "Length must not be zero");

        for (uint256 i = 0; i < _accounts.length; i++) {
            address account = _accounts[i];
            uint256 amount = _amounts[i];
            _claim(account, amount);
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
