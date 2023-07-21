// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IUniswapV2Router {
    function getAmountsOut(address factory, uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}