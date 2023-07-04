// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface ISwapRouter {
    function swapFromInternal(
        address _account,
        bytes32 _key,
        uint256 _txType,
        address _tokenIn, 
        uint256 _amountIn, 
        address _tokenOut, 
        uint256 _amountOutMin
    ) external returns (bool, address, uint256);

    // function swap(
    //     address _tokenIn, 
    //     uint256 _amountIn, 
    //     address _tokenOut, 
    //     address _receiver, 
    //     uint256 _amountOutMin 
    // ) external returns (uint256);
}