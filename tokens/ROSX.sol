// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "./LockCoin.sol";

contract ROSX is LockCoin {
    uint256 public constant MAX_SUPPLY = 200_000_000 * 10**18;

    constructor() LockCoin("Roseon", "ROSX", MAX_SUPPLY, 0) {}

    function transfer(address _receiver, uint256 _amount) public override returns (bool success) {
        _unLock(msg.sender);
        require(_amount <= getAvailableBalance(msg.sender), "Insufficient balance");
        return ERC20.transfer(_receiver, _amount);
    }

    function transferFrom(
        address _from,
        address _receiver,
        uint256 _amount
    ) public override returns (bool) {
        _unLock(_from);
        require(_amount <= getAvailableBalance(_from), "Insufficient balance");
        return ERC20.transferFrom(_from, _receiver, _amount);
    }

    function getAvailableBalance(address _account) public view returns (uint256 amount) {
        uint256 balance = balanceOf(_account);
        uint256 lockedAmount = getLockedAmount(_account);
        if (balance <= lockedAmount) return 0;
        return balance - lockedAmount;
    }
}

