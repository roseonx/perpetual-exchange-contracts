// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "./MintableBaseToken.sol";

contract LockCoin is ERC20Capped, MintableBaseToken {
    address public locker;
    address public burner;
    mapping(address => TimeLock) timeLocks;

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        uint256 totalSupply
    ) ERC20Capped(maxSupply) MintableBaseToken(name, symbol, totalSupply) {
        if (totalSupply > 0) {
            _mint(msg.sender, totalSupply);
        }

        locker = msg.sender;
        burner = msg.sender;
    }

    event Unlock(address indexed addressLock, uint256 amount);
    event AddAddressLock(address indexed addressLock, uint256 amount);
    event LockerTransferred(address indexed previousLocker, address indexed newLocker);
    event BurnerRenounced(address indexed caller);

    struct Schedule {
        uint256 unlockTime;
        uint256 amount;
    }

    struct TimeLock {
        uint256 nextIndex;
        uint256 total;
        Schedule[] schedules;
    }

    modifier onlyBurner() {
        require(burner == msg.sender, "Forbidden: Not burner");
        _;
    }

    modifier onlyLocker() {
        require(locker == msg.sender, "Forbidden: Not locker");
        _;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(BaseToken, ERC20) whenNotPaused {
        BaseToken._beforeTokenTransfer(from, to, amount);
    }

    function burn(address _account, uint256 _amount) external virtual override(MintableBaseToken) onlyMinter {
        require(msg.sender == burner, "Forbidden: Not burner");
        _burn(_account, _amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        ERC20Capped._mint(account, amount);
    }

    function renounceBurner() external onlyBurner {
        burner = address(0);
        emit BurnerRenounced(msg.sender);
    }

    function renounceLocker() external onlyLocker {
        locker = address(0);
        emit LockerTransferred(locker, address(0));
    }

    function transferLocker(address newLocker) external onlyLocker {
        require(newLocker != address(0), "New locker must not zero address");
        require(newLocker != locker, "New locker must not same as previous");
        locker = newLocker;
        emit LockerTransferred(locker, newLocker);
    }

    function _addScheduleLock(
        address _account,
        uint256 _unlockTime,
        uint256 _amount
    ) internal {
        timeLocks[_account].schedules.push(Schedule(_unlockTime, _amount));
    }

    function _updateTotalLock(
        address _account,
        uint256 _totalLock,
        uint256 _nextIndexLock
    ) internal {
        timeLocks[_account].nextIndex = _nextIndexLock;
        timeLocks[_account].total = _totalLock;
        emit AddAddressLock(_account, _totalLock);
    }

    /**
     * @dev Unlock token of "_account" with timeline lock
     */
    function _unLock(address _account) internal {
        if (timeLocks[_account].total == 0) {
            return;
        }

        TimeLock memory accountTimeLock = timeLocks[_account];
        uint256 totalUnlock = 0;
        
        while (
            accountTimeLock.nextIndex < accountTimeLock.schedules.length &&
            block.timestamp >= accountTimeLock.schedules[accountTimeLock.nextIndex].unlockTime
        ) {
            emit Unlock(_account, accountTimeLock.schedules[accountTimeLock.nextIndex].amount);
            totalUnlock += accountTimeLock.schedules[accountTimeLock.nextIndex].amount;
            accountTimeLock.nextIndex += 1;
        }

        if (totalUnlock > 0) {
            _updateTotalLock(
                _account,
                accountTimeLock.total - totalUnlock,
                accountTimeLock.nextIndex
            );
        }
    }

    /**
     * @dev get total amount lock of address
     */
    function getLockedAmount(address _account) public view returns (uint256 amount) {
        return timeLocks[_account].total;
    }

    /**
     * @dev get next shedule unlock time of address lock
     */
    function getNextScheduleUnlock(address _account) public view returns (
        uint256 index,
        uint256 unlockTime,
        uint256 amount
    ) {
        TimeLock memory accountTimeLock = timeLocks[_account];
        return (
            accountTimeLock.nextIndex,
            accountTimeLock.schedules[accountTimeLock.nextIndex].unlockTime,
            accountTimeLock.schedules[accountTimeLock.nextIndex].amount
        );
    }

    /**
     * @dev update array schedule lock token of address
     */
    function overwriteScheduleLock(
        address _account,
        uint256[] memory _arrAmount,
        uint256[] memory _arrUnlockTime
    ) public onlyLocker {
        require(_arrAmount.length > 0 && _arrAmount.length == _arrUnlockTime.length, "The parameter passed was wrong");
        require(timeLocks[_account].total > 0, "Address must in list lock");
        _overwriteTimeLockByAddress(_account, _arrAmount, _arrUnlockTime);
    }

    /**
     * @dev get lock time and amount lock by address at a time
     */
    function getScheduleLock(address _account, uint256 _index) public view returns (uint256, uint256) {
        return (
            timeLocks[_account].schedules[_index].amount,
            timeLocks[_account].schedules[_index].unlockTime
        );
    }

    /**
     * @dev add list timeline lock and total amount lock by address
     */
    function addScheduleLockByAddress(
        address _account,
        uint256[] memory _arrAmount,
        uint256[] memory _arrUnlockTime
    ) public onlyLocker {
        require(_arrAmount.length > 0 && _arrAmount.length == _arrUnlockTime.length, "The parameter passed was wrong");
        require(timeLocks[_account].total == 0, "Address must not in list lock");
        _overwriteTimeLockByAddress(_account, _arrAmount, _arrUnlockTime);
    }

    function unlock() public whenNotPaused {
        _unLock(msg.sender);
    }

    /**
     * @dev function overwrite schedule time lock and total by address lock
     */
    function _overwriteTimeLockByAddress(
        address _account,
        uint256[] memory _arrAmount,
        uint256[] memory _arrUnlockTime
    ) internal returns (uint256) {
        uint256 total = 0;
        delete timeLocks[_account].schedules;

        for (uint256 i = 0; i < _arrAmount.length; i++) {
            require(_arrUnlockTime[i] > 0, "The timeline must be greater than 0");

            if (i != _arrAmount.length - 1) {
                require(
                    _arrUnlockTime[i + 1] > _arrUnlockTime[i],
                    "The next timeline must be greater than the previous"
                );
            }
            
            _addScheduleLock(_account, _arrUnlockTime[i], _arrAmount[i]);
            total += _arrAmount[i];
        }

        _updateTotalLock(_account, total, 0);
        return total;
    }

    function getLockInfo(address _account) external view returns (uint256, uint256, uint256) {
        return (
            timeLocks[_account].nextIndex,
            timeLocks[_account].total,
            timeLocks[_account].schedules.length
        );
    }
}