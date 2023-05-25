// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IPositionHandler {
    function openNewPosition(
        bytes32 _key,
        bool _isLong, 
        uint256 _posId,
        uint256 _collateralIndex,
        bytes memory _data,
        uint256[] memory _params,
        uint256[] memory _prices, 
        address[] memory _path,
        bool _isFastExecute,
        bool _isNewPosition
    ) external;

    function modifyPosition(
        address _account,
        bool _isLong,
        uint256 _posId,
        uint256 _txType, 
        bytes memory _data,
        address[] memory path,
        uint256[] memory prices
    ) external;

    // function setPriceAndExecuteInBatch(
    //     address[] memory _path,
    //     uint256[] memory _prices,
    //     bytes32[] memory _keys, 
    //     uint256[] memory _txTypes
    // ) external;
}