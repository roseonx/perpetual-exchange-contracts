// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract BaseExecutorV2 is OwnableUpgradeable {
    mapping(address => bool) public executors;

    event SetExecutor(address indexed account, bool hasAccess);

    function initialize() internal virtual {
        if (owner() == address(0)) {
            __Ownable_init();
        }
    }

    function setExecutor(address _account, bool _hasAccess) onlyOwner external {
        executors[_account] = _hasAccess;
        emit SetExecutor(_account, _hasAccess);
    }

    function _isExecutor(address _account) internal view returns (bool) {
        return executors[_account];
    }
}