// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../constants/BaseConstants.sol";
import "../../swap/interfaces/IUniswapV2Factory.sol";
import "../../swap/interfaces/IUniswapV2Router.sol";
import "../../swap/interfaces/IUniswapV2Pair.sol";
import "../../swap/interfaces/IUniswapV3Pool.sol";
import "../../swap/interfaces/IUniswapV3SwapCallback.sol";
import "../../core/interfaces/IPriceManager.sol";
import "../core/interfaces/IVaultV2.sol";
import "../core/interfaces/ISettingsManagerV2.sol";
import "./interfaces/ISwapRouterV2.sol";

import {SwapRequest, VaultBond} from "../../constants/Structs.sol";

pragma solidity ^0.8.12;

contract SwapRouterV2 is OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, BaseConstants, ISwapRouterV2, IUniswapV3SwapCallback {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    IVaultV2 public vault;
    ISettingsManagerV2 public settingsManager;
    IPriceManager public priceManager;
    address public positionRouter;

    bool public isEnableContractCall;
    bool public isEnableExternalSwap;
    bool public isEnableVaultSwap;
    bool public isEnableUniswapV3;
    uint256 public swapFee;

    //V3
    address public uniswapV3Router;
    mapping(address => address) public swapV3Pools;
    mapping(address => uint256) public vaultReserveAmounts;

    //V2
    address public swapV2Factory;
    address public swapV2Router;

    event FinalInitialized(
        address vault,
        address settingsManager,
        address priceManager,
        address positionRouter
    );
    
    event EnableContractCall(bool isEnableContractCall);
    event EnableExternalSwap(bool isEnableExternalSwap);
    event EnableVaultSwap(bool isEnableVaultSwap);
    event SetSwapFee(uint256 swapFee);
    event SetVaultReserveAmount(address token, uint256 reserveAmount);

    event EnableUniswapV3(bool isEnableUniswapV3);
    event SetUniswapV3Router(address uniswapV3Router);
    event SetSwapV3Pool(address colalteralToken, address poolV3Address);

    event SetSwapV2Factory(address swapV2Factory);
    event SetSwapV2Router(address swapV2Router);

    event Swap(
        bytes32 key, 
        address sender, 
        address indexed tokenIn, 
        uint256 amountIn, 
        address indexed tokenOut, 
        address indexed receiver, 
        uint256 amountOut, 
        bool isVaultSwap
    );

    function initialize(
        address _vault,
        address _settingsManager, 
        address _priceManager,
        address _positionRouter
    ) public initializer {
        __Ownable_init();
        _finalInitialize(
            _vault, 
            _settingsManager, 
            _priceManager,
            _positionRouter
        );
    }

    function _finalInitialize(
        address _vault,
        address _settingsManager, 
        address _priceManager,
        address _positionRouter
    ) internal {
        require(AddressUpgradeable.isContract(_vault) 
            && AddressUpgradeable.isContract(_settingsManager)
            && AddressUpgradeable.isContract(_priceManager)
            && AddressUpgradeable.isContract(_positionRouter), "Invalid contract");
    
        vault = IVaultV2(_vault);
        settingsManager = ISettingsManagerV2(_settingsManager);
        priceManager = IPriceManager(_priceManager);
        positionRouter = _positionRouter;
        emit FinalInitialized(
            _vault,
            _settingsManager, 
            _priceManager,
            _positionRouter
        );
    }

    function _authorizeUpgrade(address) internal override onlyOwner {
        
    }

    function setEnableContractCall(bool _isEnableContractCall) external onlyOwner {
        isEnableContractCall = _isEnableContractCall;
        emit EnableContractCall(_isEnableContractCall);
    }

    function setEnableExternalSwap(bool _isEnableExternalSwap) external onlyOwner {
        isEnableExternalSwap = _isEnableExternalSwap;
        emit EnableExternalSwap(_isEnableExternalSwap);
    }

    function setEnableVaultSwap(bool _isEnableVaultSwap) external onlyOwner {
        isEnableVaultSwap = _isEnableVaultSwap;
        emit EnableVaultSwap(_isEnableVaultSwap);
    }

    function setSwapV2Factory(address _swapV2Factory) external onlyOwner {
        swapV2Factory = _swapV2Factory;
        emit SetSwapV2Factory(_swapV2Factory);
    }

    function setSwapV2Router(address _swapV2Router) external onlyOwner {
        swapV2Router = _swapV2Router;
        emit SetSwapV2Router(_swapV2Router);
    }

    function setEnableUniswapV3(bool _isEnableUniswapV3) external onlyOwner {
        isEnableUniswapV3 = _isEnableUniswapV3;
        emit EnableUniswapV3(_isEnableUniswapV3);
    }

    function setUniswapV3Router(address _uniswapV3Router) external onlyOwner {
        uniswapV3Router = _uniswapV3Router;
        emit SetUniswapV3Router(_uniswapV3Router);
    }

    function setSwapPoolV3(address _token, address _poolV3Address) external onlyOwner {
        swapV3Pools[_token] = _poolV3Address;
        emit SetSwapV3Pool(_token, _poolV3Address);
    }

    function setVaultReserveAmount(address _token, uint256 _reserveAmount) external onlyOwner {
        vaultReserveAmounts[_token] = _reserveAmount;
        emit SetVaultReserveAmount(_token, _reserveAmount);
    }

    function swapFromInternal(
        address _account,
        bytes32 _key,
        uint256 _txType,
        uint256 _amountIn, 
        uint256 _amountOutMin,
        address[] memory _path
    ) external override nonReentrant returns (address, uint256) {
        require(msg.sender == positionRouter, "Forbidden");
        require(_amountIn > 0 && _amountOutMin > 0, "Invalid amount");
        require(_path.length > 2, "Invalid path length");
        VaultBond memory bond = vault.getBond(_key, _txType);
        require(_amountIn >= bond.amount && _amountIn > 0, "Insufficient bond amount to swap");
        require(_path[1] == bond.token && _path[1] != address(0), "Invalid bond token");
        require(_account == bond.owner && _account != address(0), "Invalid bond owner");
        vault.decreaseBond(_key, _account, _txType);
        uint256 amountOut = _swap(
            _key,
            true,
            _path[1], 
            _amountIn, 
            _getLastPath(_path),
            address(vault),
            address(vault)
        );
        require(amountOut > 0 && amountOut >= _amountOutMin, "Too little received");
        return (_getLastPath(_path), amountOut);
    }

    function swap(
        address _receiver,
        uint256 _amountIn, 
        uint256 _amountOutMin,
        address[] memory _path
    ) external override nonReentrant returns (bytes memory) {
        _isExternalSwapEnabled();
        _verifyCaller(msg.sender);
        require(_amountOutMin > 0, "AmountOutMin must greater than zero");
        require(_path.length >= 3, "Insufficient path length");
        uint256 amountOut = _swap(
            "0x", 
            false,
            _path[1], 
            _amountIn, 
            _getLastPath(_path), 
            msg.sender, 
            _receiver
        );
        require(amountOut >= _amountOutMin, "Too little received");

        return abi.encode(amountOut);
    }

    function _swap(
        bytes32 _key, 
        bool _hasPaid,
        address _tokenIn, 
        uint256 _amountIn, 
        address _tokenOut, 
        address _sender, 
        address _receiver
    ) internal returns (uint256) {
        require(IERC20Upgradeable(_tokenIn).balanceOf(_sender) >= _amountIn, "Insufficient balance");
        require(IERC20Upgradeable(_tokenIn).allowance(_sender, address(vault)) >= _amountIn, 
            "Allowance not approved");
        uint256 amountOut;
        bool isFastExecute;

        if (isEnableVaultSwap) {
            (amountOut, isFastExecute) = _vaultSwap(
                _tokenIn, 
                _amountIn, 
                _tokenOut, 
                _sender, 
                _receiver,  
                _hasPaid
            );
        }

        if (!isEnableVaultSwap || !isFastExecute) {
            amountOut = isEnableUniswapV3 ? 
                _ammSwapV3(
                    _tokenIn, 
                    _amountIn, 
                    _tokenOut, 
                    _sender, 
                    _receiver, 
                    _key, 
                    _hasPaid
                ) : 
                _ammSwapV2(
                    _tokenIn, 
                    _amountIn, 
                    _tokenOut, 
                    _sender, 
                    _receiver, 
                    _hasPaid
                );
        }
        require(amountOut > 0, "Invalid received swap amount");

        emit Swap(
            _key, 
            _sender, 
            _tokenIn, 
            _amountIn, 
            _tokenOut, 
            _receiver, 
            amountOut, 
            isEnableVaultSwap && isFastExecute
        );

        return amountOut;
    }

    function _vaultSwap(
        address _tokenIn, 
        uint256 _amountIn, 
        address _tokenOut, 
        address _sender, 
        address _receiver, 
        bool _hasPaid
    ) internal returns (uint256, bool) {
        require(!AddressUpgradeable.isContract(_sender), "Not allowed");
        (uint256 tokenInPrice, uint256 tokenOutPrice, bool isFastExecute) = _getPricesAndCheckFastExecute(_tokenIn, _tokenOut);

        if (!isFastExecute) {
            return (0, false);
        }

        uint256 amountInUSD = _fromTokenToUSD(_tokenIn, _amountIn, tokenInPrice);
        uint256 fee = amountInUSD * swapFee / BASIS_POINTS_DIVISOR;
        uint256 amountOutAfterFee = _fromUSDToToken(_tokenOut, amountInUSD - fee, tokenOutPrice);

        if (_receiver != address(vault) && vault.getTokenBalance(_tokenOut) < amountOutAfterFee) {
            return (0, false);
        }

        if (!_hasPaid) {
            _transferFrom(_tokenIn, _sender, _amountIn);
            _transferTo(_tokenIn, _amountIn, address(vault));
            vault.updateBalance(_tokenIn);
        }

        if (_receiver != address(vault)) {
            _takeAssetOut(_receiver, fee, amountOutAfterFee, _tokenOut);
        }

        return (amountOutAfterFee, true);
    }

    function _ammSwapV2(
        address _tokenIn, 
        uint256 _amountIn, 
        address _tokenOut, 
        address _sender, 
        address _receiver, 
        bool _hasPaid
    ) internal returns (uint256) {
        require(swapV2Factory != address(0), "SwapV2Factory has not been configured yet");
        address swapV2Pool = IUniswapV2Factory(swapV2Factory).getPair(_tokenIn, _tokenOut);
        require(swapV2Pool != address(0), "Invalid swapV2Pool");
        require(swapV3Pools[_tokenIn] == _tokenOut, "Invalid pool address");

        if (!_hasPaid) {
            _transferFrom(_tokenIn, _sender, _amountIn);
            _transferTo(_tokenIn, _amountIn, swapV2Pool);
        } else {
            //TODO: Must implement
        }

        address token0 = IUniswapV2Pair(swapV2Pool).token0();
        bool isZeroForOne = _tokenIn == token0;
        address[] memory path = new address[](2);
        path[0] = token0;
        path[1] = isZeroForOne ? _tokenOut : _tokenIn;
        uint[] memory estAmounts = IUniswapV2Router(swapV2Router).getAmountsOut(swapV2Factory, _amountIn, path);
        require(estAmounts.length == 2, "Invalid estAmounts length");
        require(estAmounts[1] > 0, "Invalid estAmounts");

        if (isZeroForOne) {
            IUniswapV2Pair(swapV2Pool).swap(
                0,
                estAmounts[1],
                _receiver,
                new bytes(0)
            );
        } else {
            IUniswapV2Pair(swapV2Pool).swap(
                estAmounts[1],
                0,
                _receiver,
                new bytes(0)
            );
        }

        return estAmounts[1];
    }

    function _ammSwapV3(
        address _tokenIn, 
        uint256 _amountIn, 
        address _tokenOut, 
        address _sender, 
        address _receiver, 
        bytes32 _key, 
        bool _hasPaid
    ) internal returns (uint256) {
        require(uniswapV3Router != address(0), "Uniswap positionRouter has not configured yet");
        require(swapV3Pools[_tokenIn] != address(0), "Pool has not configured yet");
        require(swapV3Pools[_tokenIn] == _tokenOut, "Invalid pool address");

        if (!_hasPaid) {
            _transferFrom(_tokenIn, _sender, _amountIn);
        }

        bool zeroForOne = _tokenIn < _tokenOut;
        SwapRequest memory swapRequest = SwapRequest(
                _key, 
                zeroForOne ? _tokenIn : _tokenOut, 
                swapV3Pools[_tokenIn], 
                _amountIn
        );
        bytes memory callData = abi.encode(swapRequest);
        (int256 amount0, int256 amount1) = IUniswapV3Pool(swapV3Pools[_tokenIn]).swap(
            _receiver, 
            zeroForOne, 
            int256(_amountIn), 
            0, 
            callData
        );

        return uint256(zeroForOne ? amount1 : amount0);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        require(amount0Delta != 0 && amount1Delta != 0, "Swap failed");
        SwapRequest memory swapRequest = abi.decode(data, (SwapRequest));
        uint256 transferAmount = swapRequest.amountIn;
        require(transferAmount > 0, "Invalid swap callback amount");
        address tokenIn = swapRequest.tokenIn;
        require(msg.sender == swapV3Pools[tokenIn], "Invalid pool sender");
        require(IERC20Upgradeable(tokenIn).balanceOf(address(this)) >= transferAmount, "Insufficient to swap");
        IERC20Upgradeable(tokenIn).safeTransfer(swapRequest.pool, transferAmount);
    }

    function _takeAssetOut(
        address _receiver,
        uint256 fee,
        uint256 amountOutAfterFee, 
        address _tokenOut
    ) internal {
        vault.takeAssetOut(bytes32(0), _receiver, fee, amountOutAfterFee + fee, _tokenOut, PRICE_PRECISION);
    }

    function _fromTokenToUSD(address _token, uint256 _tokenAmount, uint256 _price) internal view returns (uint256) {
        if (_tokenAmount == 0) {
            return 0;
        }

        uint256 decimals = priceManager.tokenDecimals(_token);
        require(decimals > 0, "Invalid decimals while converting from token to USD");
        return (_tokenAmount * _price) / (10 ** decimals);
    }

    function _fromUSDToToken(address _token, uint256 _usdAmount, uint256 _price) internal view returns (uint256) {
        if (_usdAmount == 0) {
            return 0;
        }
        
        uint256 decimals = priceManager.tokenDecimals(_token);
        require(decimals > 0, "Invalid decimals while converting from USD to token");
        return (_usdAmount * (10 ** decimals)) / _price;
    }

    function _transferFrom(address _token, address _account, uint256 _amount) internal {
        IERC20Upgradeable(_token).safeTransferFrom(_account, address(this), _amount);
    }

    function _transferTo(address _token, uint256 _amount, address _receiver) internal {
        IERC20Upgradeable(_token).safeTransfer(_receiver, _amount);
    }

    function _getLastPath(address[] memory _path) internal pure returns (address) {
        return _path[_path.length - 1];
    }

    function _getPricesAndCheckFastExecute(
        address _tokenIn, 
        address _tokenOut
    ) internal view returns (uint256, uint256, bool) {
        address[] memory tokens = new address[](2);
        tokens[0] = _tokenIn;
        tokens[1] = _tokenOut;
        (uint256[] memory prices, bool isFastExecute) = priceManager.getLatestSynchronizedPrices(tokens);
        return (prices[0], prices[1], isFastExecute);
    }

    function _verifyCaller(address _caller) internal view {
        if (!isEnableContractCall) {
            require(!AddressUpgradeable.isContract(_caller), "Not allowed");
        }
    }

    function _isExternalSwapEnabled() internal view {
        if (!isEnableExternalSwap) {
            revert("Not allowed");
        }
    }
}