// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {Position, OrderInfo, OrderType} from "../../constants/Structs.sol";

interface IVaultUtils {
    function validateConfirmDelay(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        bool _raise
    ) external view returns (bool);

    function validateDecreasePosition(
        address _indexToken,
        bool _isLong,
        bool _raise, 
        uint256 _indexPrice,
        Position memory _position
    ) external view returns (bool);

    function validateLiquidation(
        address _account,
        address _indexToken,
        bool _isLong,
        bool _raise, 
        uint256 _indexPrice,
        Position memory _position
    ) external view returns (uint256, uint256);

    function validatePositionData(
        bool _isLong,
        address _indexToken,
        OrderType _orderType,
        uint256 _latestTokenPrice,
        uint256[] memory _params,
        bool _raise
    ) external view returns (bool);

    function validateSizeCollateralAmount(uint256 _size, uint256 _collateral) external view;

    function validateTrailingStopInputData(
        bytes32 _key,
        bool _isLong,
        uint256[] memory _params,
        uint256 _indexPrice
    ) external view returns (bool);

    function validateTrailingStopPrice(
        bool _isLong,
        bytes32 _key,
        bool _raise,
        uint256 _indexPrice
    ) external view returns (bool);

    function validateTrigger(
        bool _isLong,
        uint256 _indexPrice,
        OrderInfo memory _order
    ) external pure returns (uint8);

    function validateTrigger(
        bytes32 _key,
        uint256 _indexPrice
    ) external view returns (uint8);

    function validateAmountIn(
        address _collateralToken,
        uint256 _amountIn,
        uint256 _collateralPrice
    ) external view returns (uint256);

    function validateAddCollateral(
        uint256 _amountIn,
        address _collateralToken,
        uint256 _collateralPrice,
        bytes32 _key
    ) external view returns (uint256);

    function validateAddCollateral(
        uint256 _positionSize, 
        uint256 _positionCollateral, 
        uint256 _amountIn,
        address _collateralToken,
        uint256 _collateralPrice
    ) external view returns (uint256);

    function validateRemoveCollateral(
        uint256 _amountIn, 
        bool _isLong,
        address _indexToken,
        uint256 _indexPrice,
        bytes32 _key
    ) external;

    function validateRemoveCollateral(
        uint256 _amountIn, 
        bool _isLong,
        address _indexToken,
        uint256 _indexPrice,
        Position memory _position
    ) external;

    function beforeDecreasePosition(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _sizeDelta,
        uint256 _indexPrice,
        bool _isInternal
    ) external view returns (uint256[4] memory, bool, bool, Position memory);
}