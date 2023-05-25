// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {VaultBond} from "../../constants/Structs.sol";

interface IVault {
    function accountDeltaAndFeeIntoTotalBalance(
        bool _hasProfit, 
        uint256 _adjustDelta, 
        uint256 _fee,
        address _token,
        uint256 _tokenPrice
    ) external;

    function distributeFee(address _account, address _refer, uint256 _fee, address _token) external;

    function takeAssetIn(
        address _account, 
        uint256 _amount, 
        address _token,
        bytes32 _key,
        uint256 _txType
    ) external;

    function collectVaultFee(
        address _refer, 
        uint256 _usdAmount
    ) external;

    function takeAssetOut(
        address _account, 
        address _refer, 
        uint256 _fee, 
        uint256 _usdOut, 
        address _token, 
        uint256 _tokenPrice
    ) external;

    function takeAssetBack(
        address _account, 
        bytes32 _key,
        uint256 _txType
    ) external;

    function decreaseBond(bytes32 _key, address _account, uint256 _txType) external;

    function transferBounty(address _account, uint256 _amount) external;

    function ROLP() external view returns(address);

    function RUSD() external view returns(address);

    function totalUSD() external view returns(uint256);

    function totalROLP() external view returns(uint256);

    function updateTotalROLP() external;

    function updateBalance(address _token) external;

    function updateBalances() external;

    function getBalance(address _token) external view returns (uint256);

    function getBalances() external view returns (address[] memory, uint256[] memory);

    function convertRUSD(
        address _account,
        address _recipient, 
        address _tokenOut, 
        uint256 _amount
    ) external;

    function stake(address _account, address _token, uint256 _amount) external;

    function unstake(address _tokenOut, uint256 _rolpAmount, address _receiver) external;

    function emergencyDeposit(address _token, uint256 _amount) external;

    function getBond(bytes32 _key, uint256 _txType) external view returns (VaultBond memory);

    function getBondOwner(bytes32 _key, uint256 _txType) external view returns (address);

    function getBondToken(bytes32 _key, uint256 _txType) external view returns (address);

    function getBondAmount(bytes32 _key, uint256 _txType) external view returns (uint256);
}