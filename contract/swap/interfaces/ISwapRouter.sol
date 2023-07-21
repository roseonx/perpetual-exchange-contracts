// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface ISwapRouter {
    function swapFromInternal(
        address _account,
        bytes32 _key,
        uint256 _txType,
        uint256 _amountIn, 
        uint256 _amountOutMin,
        address[] memory _path
    ) external returns (address, uint256);

    function swap(
        address _account,
        address _receiver,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] memory _path
    ) external returns (bytes memory);
}