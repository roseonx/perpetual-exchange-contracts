// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IPositionHandler {
    // function openNewPosition(
    //     bytes32 _key,
    //     bool _isFastExecute,
    //     bool _isNewPosition,
    //     uint256[] memory _params,
    //     uint256[] memory _prices, 
    //     address[] memory _path,
    //     bytes memory _data
    // ) external;

    function modifyPosition(
        bytes32 _key,
        uint256 _txType, 
        address[] memory _path,
        uint256[] memory _prices,
        bytes memory _data
    ) external;
}