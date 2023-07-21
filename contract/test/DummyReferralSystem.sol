// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/interfaces/IReferralSystem.sol";

contract DummyReferralSystem is IReferralSystem, Ownable {
    mapping(address => address) public referrals;
    mapping(address => ReferrerInfo) public referrers;

    struct ReferrerInfo {
        uint256 discountPercentage;
        uint256 rebatePercentage;
    }
    
    event SetReferrerBonus(address indexed referrer, uint256 discountPercentage, uint256 rebatePercentage);

    function setReferrerBonus(address _referrer, uint256 _discountPercentage, uint256 _rebatePercentage) external onlyOwner {
        referrers[_referrer].discountPercentage = _discountPercentage;
        referrers[_referrer].rebatePercentage = _rebatePercentage;
        emit SetReferrerBonus(_referrer, _discountPercentage, _rebatePercentage);
    }

    function setReferrer(address _account, address _referrer) external onlyOwner {
        referrals[_account] = _referrer;
    }

    function getDiscountable(address _account) external view returns(address, uint256, uint256) {
        return (referrals[_account], referrers[_account].discountPercentage, referrers[_account].rebatePercentage);
    }
}