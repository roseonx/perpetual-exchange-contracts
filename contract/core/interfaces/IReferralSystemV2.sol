// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IReferralSystemV2 {
    function getDiscountable(address _account) external view returns (
        uint256, //discountPercentage
        uint256, //rebatePercentage
        uint256, //esRebatePercentage
        address //referrer
    );

    function applyDiscount(
        uint256 _fee,
        address _account,
        bool _isApplyDiscountFee,
        bool _isApplyRebate
    ) external returns (
        uint256, //discountPercentage
        uint256, //rebatePercentage
        uint256, //esRebatePercentage
        address //referrer
    );
}