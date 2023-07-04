// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/ISwapRouter.sol";
import "./interfaces/ISwapHandler.sol";

pragma solidity ^0.8.12;

contract SwapRouter is Ownable, ReentrancyGuard, ISwapRouter {
    ISwapHandler public swapHandler;
    address public router;

    event SetSwapHandler(address swapHandler);
    event SetRouter(address router);

    function setSwapHandler(address _swapHandler) external onlyOwner {
        _isValidContract(_swapHandler);
        swapHandler = ISwapHandler(_swapHandler);
        emit SetSwapHandler(_swapHandler);
    }

    function setPositionRouter(address _router) external onlyOwner {
        _isValidContract(_router);
        router = _router;
        emit SetRouter(_router);
    }

    function _isValidContract(address _contract) internal view {
        require(_contract != address(0) && Address.isContract(_contract), "Invalid contract address");
    }

    function swapFromInternal(
        address _account,
        bytes32 _key,
        uint256 _txType,
        address _tokenIn, 
        uint256 _amountIn, 
        address _tokenOut, 
        uint256 _amountOutMin
    ) external override nonReentrant returns (bool, address, uint256) {
        require(msg.sender == router, "Forbidden: Not router");
        require(_amountOutMin > 0, "Zero amountOutMin");
        _isValidContract(address(swapHandler));

        try ISwapHandler(swapHandler).swapFromInternal(
            _account,
            _key,
            _txType,
            _tokenIn, 
            _amountIn, 
            _tokenOut, 
            _amountOutMin
        ) returns (address tokenOut, uint256 amountOut) {
            return (true, tokenOut, amountOut);
        } catch {
            return (false, address(0), 0);
        }
    }
}