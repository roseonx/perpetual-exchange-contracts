// // SPDX-License-Identifier: MIT

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// import "../constants/BaseConstants.sol";
// import "./interfaces/ISwapRouter.sol";
// import "./interfaces/IUniswapV2Factory.sol";
// import "./interfaces/IUniswapV2Router.sol";
// import "./interfaces/IUniswapV2Pair.sol";
// import "./interfaces/IUniswapV3Pool.sol";
// import "./interfaces/IUniswapV3SwapCallback.sol";
// import "../core/interfaces/IVault.sol";
// import "../core/interfaces/IPriceManager.sol";
// import "../core/interfaces/ISettingsManager.sol";

// import {SwapRequest, VaultBond} from "../constants/Structs.sol";

// pragma solidity ^0.8.12;

// contract SwapRouter is Ownable, ReentrancyGuard, BaseConstants, ISwapRouter, IUniswapV3SwapCallback {
//     using SafeERC20 for IERC20;
    
//     IVault public vault;
//     ISettingsManager public settingsManager;
//     IPriceManager public priceManager;
//     address public positionRouter;

//     bool public isEnableVaultSwap;
//     bool public isEnableUniswapV3;
//     uint256 public swapFee;

//     //V3
//     address public uniswapV3Router;
//     mapping(address => address) public swapV3Pools;

//     //V2
//     address public swapV2Factory;
//     address public swapV2Router;

//     //Vault config events
//     event SetVault(address vault);
//     event SetSettingsManager(address settingsManager);
//     event SetPriceManager(address priceManager);
//     event SetPositionRouter(address positionRouter);
    
//     //Swap events
//     event SetEnableVaultSwap(bool isEnableVaultSwap);
//     event SetSwapFee(uint256 swapFee);

//     event SetEnableUniswapV3(bool isEnableUniswapV3);
//     event SetUniswapV3Router(address uniswapV3Router);
//     event SetSwapV3Pool(address colalteralToken, address poolV3Address);

//     event SetSwapV2Factory(address swapV2Factory);
//     event SetSwapV2Router(address swapV2Router);

//     event Swap(
//         bytes32 key, 
//         address sender, 
//         address indexed tokenIn, 
//         uint256 amountIn, 
//         address indexed tokenOut, 
//         address indexed receiver, 
//         uint256 amountOut, 
//         bool isVaultSwap
//     );

//     constructor(address _vault, address _settingsManager, address _priceManager) {
//         require(Address.isContract(_vault), "Invalid vault");
//         require(Address.isContract(_settingsManager), "Invalid settingsManager");
//         require(Address.isContract(_priceManager), "Invalid priceManager");
       
//         vault = IVault(_vault);
//         emit SetVault(_vault);

//         settingsManager = ISettingsManager(_settingsManager);
//         emit SetSettingsManager(_settingsManager);

//         priceManager = IPriceManager(_priceManager);
//         emit SetPriceManager(_priceManager);
//     }

//     function setVault(address _vault) external onlyOwner {
//         require(Address.isContract(_vault), "Invalid vault");
//         vault = IVault(_vault);
//         emit SetVault(_vault);
//     }

//     function setPositionRouter(address _router) external onlyOwner {
//         require(Address.isContract(_router), "Invalid positionRouter");
//         positionRouter = _router;
//         emit SetPositionRouter(_router);
//     }

//     function setSettingsManager(address _settingsManager) external onlyOwner {
//         require(Address.isContract(_settingsManager), "Invalid settingsManager");
//         settingsManager = ISettingsManager(_settingsManager);
//         emit SetSettingsManager(_settingsManager);
//     }

//     function setPriceManager(address _priceManager) external onlyOwner {
//         require(Address.isContract(_priceManager), "Invalid priceManager");
//         priceManager = IPriceManager(_priceManager);
//         emit SetPriceManager(_priceManager);
//     }

//     function setEnableVaultSwap(bool _isEnableVaultSwap) external onlyOwner {
//         isEnableVaultSwap = _isEnableVaultSwap;
//         emit SetEnableVaultSwap(_isEnableVaultSwap);
//     }

//     function setSwapV2Factory(address _swapV2Factory) external onlyOwner {
//         swapV2Factory = _swapV2Factory;
//         emit SetSwapV2Factory(_swapV2Factory);
//     }

//     function setSwapV2Router(address _swapV2Router) external onlyOwner {
//         swapV2Router = _swapV2Router;
//         emit SetSwapV2Router(_swapV2Router);
//     }

//     function setEnableUniswapV3(bool _isEnableUniswapV3) external onlyOwner {
//         isEnableUniswapV3 = _isEnableUniswapV3;
//         emit SetEnableUniswapV3(_isEnableUniswapV3);
//     }

//     function setUniswapV3Router(address _uniswapV3Router) external onlyOwner {
//         uniswapV3Router = _uniswapV3Router;
//         emit SetUniswapV3Router(_uniswapV3Router);
//     }

//     function setSwapPoolV3(address _token, address _poolV3Address) external onlyOwner {
//         swapV3Pools[_token] = _poolV3Address;
//         emit SetSwapV3Pool(_token, _poolV3Address);
//     }

//     function swapFromInternal(
//         address _account,
//         bytes32 _key,
//         uint256 _txType,
//         uint256 _amountIn, 
//         uint256 _amountOutMin,
//         address[] memory _path
//     ) external override nonReentrant returns (address, uint256) {
//         require(msg.sender == positionRouter, "Forbidden");
//         require(_amountIn > 0, "Invalid amountIn");
//         require(_amountOutMin > 0, "Invalid amountOutMin");
//         require(_path.length > 2, "Invalid path length");
//         VaultBond memory bond = vault.getBond(_key, _txType);
//         require(_amountIn >= bond.amount && _amountIn > 0, "Insufficient bond amount to swap");
//         require(_path[1] == bond.token && _path[1] != address(0), "Invalid bond token to swap");
//         require(_account == bond.owner && _account != address(0), "Invalid bond owner to swap");
//         uint256 amountOut = _swap(
//             _key,
//             true,
//             _path[1], 
//             _amountIn, 
//             _getLastPath(_path),
//             address(vault),
//             address(vault)
//         );
//         require(amountOut > 0 && amountOut >= _amountOutMin, "Too little received");
//         vault.decreaseBond(_key, _account, _txType);
//         return (_getLastPath(_path), amountOut);
//     }

//     function swap(
//         address _account,
//         address _receiver,
//         uint256 _amountIn, 
//         uint256 _amountOutMin,
//         address[] memory _path
//     ) external override nonReentrant returns (bytes memory) {
//         require(_amountOutMin > 0, "AmountOutMin must greater than zero");
//         address tokenIn;
//         address tokenOut;

//         {
//             tokenIn = _path[1];
//             tokenOut = _path[_path.length - 1];
//         }

//         require(IERC20(tokenIn).balanceOf(_account) >= _amountIn, "Insufficient swap amount");
//         require(IERC20(tokenIn).allowance(_account, address(this)) >= _amountIn, 
//             "Please approve vault to use swap amount first");
//         uint256 amountOut = _swap(
//             "0x", 
//             false,
//             tokenIn, 
//             _amountIn, 
//             tokenOut, 
//             _account, 
//             _receiver
//         );
//         require(amountOut >= _amountOutMin, "Too little received");

//         return abi.encode(amountOut);
//     }

//     function _swap(
//         bytes32 _key, 
//         bool _hasPaid,
//         address _tokenIn, 
//         uint256 _amountIn, 
//         address _tokenOut, 
//         address _sender, 
//         address _receiver
//     ) internal returns (uint256) {
//         uint256 amountOut;
//         bool isFastExecute;

//         if (isEnableVaultSwap) {
//             (amountOut, isFastExecute) = _vaultSwap(
//                 _tokenIn, 
//                 _amountIn, 
//                 _tokenOut, 
//                 _sender, 
//                 _receiver,  
//                 _hasPaid
//             );
//         }

//         if (!isEnableVaultSwap || !isFastExecute) {
//             amountOut = isEnableUniswapV3 ? 
//                 _ammSwapV3(
//                     _tokenIn, 
//                     _amountIn, 
//                     _tokenOut, 
//                     _sender, 
//                     _receiver, 
//                     _key, 
//                     _hasPaid
//                 ) : 
//                 _ammSwapV2(
//                     _tokenIn, 
//                     _amountIn, 
//                     _tokenOut, 
//                     _sender, 
//                     _receiver, 
//                     _hasPaid
//                 );
//         }
//         require(amountOut > 0, "Invalid received swap amount");

//         emit Swap(
//             _key, 
//             _sender, 
//             _tokenIn, 
//             _amountIn, 
//             _tokenOut, 
//             _receiver, 
//             amountOut, 
//             isEnableVaultSwap && isFastExecute
//         );

//         return amountOut;
//     }

//     function _vaultSwap(
//         address _tokenIn, 
//         uint256 _amountIn, 
//         address _tokenOut, 
//         address _sender, 
//         address _receiver, 
//         bool _hasPaid
//     ) internal returns (uint256, bool) {
//         uint256 tokenInPrice;
//         uint256 tokenOutPrice;
//         bool isFastExecute;

//         {
//             (tokenInPrice, isFastExecute) = _isFastExecute(_tokenIn);
//             (tokenOutPrice, isFastExecute) = _isFastExecute(_tokenOut);
//         }

//         if (!isFastExecute) {
//             return (0, false);
//         }

//         uint256 amountInUSD = _fromTokenToUSD(_tokenIn, _amountIn, tokenInPrice);
//         uint256 fee = amountInUSD * swapFee / BASIS_POINTS_DIVISOR;
//         uint256 amountOutAfterFee = _fromUSDToToken(_tokenOut, amountInUSD - fee, tokenOutPrice);

//         if (_receiver != address(vault) && vault.getTokenBalance(_tokenOut) < amountOutAfterFee) {
//             return (0, false);
//         }

//         if (!_hasPaid) {
//             _transferFrom(_tokenIn, _sender, _amountIn);
//             _transferTo(_tokenIn, _amountIn, address(vault));
//         }

//         if (_receiver != address(vault)) {
//             _takeAssetOut(_receiver, fee, amountOutAfterFee, _tokenOut);
//         }

//         return (amountOutAfterFee, true);
//     }

//     function _ammSwapV2(
//         address _tokenIn, 
//         uint256 _amountIn, 
//         address _tokenOut, 
//         address _sender, 
//         address _receiver, 
//         bool _hasPaid
//     ) internal returns (uint256) {
//         require(swapV2Factory != address(0), "SwapV2Factory has not been configured yet");
//         address swapV2Pool = IUniswapV2Factory(swapV2Factory).getPair(_tokenIn, _tokenOut);
//         require(swapV2Pool != address(0), "Invalid swapV2Pool");
//         require(swapV3Pools[_tokenIn] == _tokenOut, "Invalid pool address");

//         if (!_hasPaid) {
//             _transferFrom(_tokenIn, _sender, _amountIn);
//             _transferTo(_tokenIn, _amountIn, swapV2Pool);
//         } else {
//             //TODO: Must implement
//         }

//         address token0 = IUniswapV2Pair(swapV2Pool).token0();
//         bool isZeroForOne = _tokenIn == token0;
//         address[] memory path = new address[](2);
//         path[0] = token0;
//         path[1] = isZeroForOne ? _tokenOut : _tokenIn;
//         uint[] memory estAmounts = IUniswapV2Router(swapV2Router).getAmountsOut(swapV2Factory, _amountIn, path);
//         require(estAmounts.length == 2, "Invalid estAmounts length");
//         require(estAmounts[1] > 0, "Invalid estAmounts");

//         if (isZeroForOne) {
//             IUniswapV2Pair(swapV2Pool).swap(
//                 0,
//                 estAmounts[1],
//                 _receiver,
//                 new bytes(0)
//             );
//         } else {
//             IUniswapV2Pair(swapV2Pool).swap(
//                 estAmounts[1],
//                 0,
//                 _receiver,
//                 new bytes(0)
//             );
//         }

//         return estAmounts[1];
//     }

//     function _ammSwapV3(
//         address _tokenIn, 
//         uint256 _amountIn, 
//         address _tokenOut, 
//         address _sender, 
//         address _receiver, 
//         bytes32 _key, 
//         bool _hasPaid
//     ) internal returns (uint256) {
//         require(uniswapV3Router != address(0), "Uniswap positionRouter has not configured yet");
//         require(swapV3Pools[_tokenIn] != address(0), "Pool has not configured yet");
//         require(swapV3Pools[_tokenIn] == _tokenOut, "Invalid pool address");

//         if (!_hasPaid) {
//             _transferFrom(_tokenIn, _sender, _amountIn);
//         }

//         bool zeroForOne = _tokenIn < _tokenOut;
//         SwapRequest memory swapRequest = SwapRequest(
//                 _key, 
//                 zeroForOne ? _tokenIn : _tokenOut, 
//                 swapV3Pools[_tokenIn], 
//                 _amountIn
//         );
//         bytes memory callData = abi.encode(swapRequest);
//         (int256 amount0, int256 amount1) = IUniswapV3Pool(swapV3Pools[_tokenIn]).swap(
//             _receiver, 
//             zeroForOne, 
//             int256(_amountIn), 
//             0, 
//             callData
//         );

//         return uint256(zeroForOne ? amount1 : amount0);
//     }

//     function uniswapV3SwapCallback(
//         int256 amount0Delta,
//         int256 amount1Delta,
//         bytes calldata data
//     ) external {
//         SwapRequest memory swapRequest = abi.decode(data, (SwapRequest));
//         uint256 transferAmount = swapRequest.amountIn;
//         require(transferAmount > 0, "Invalid swap callback amount");
//         address tokenIn = swapRequest.tokenIn;
//         require(msg.sender == swapV3Pools[tokenIn], "Invalid pool sender");
//         require(IERC20(tokenIn).balanceOf(address(this)) >= transferAmount, "Insufficient to swap");
//         IERC20(tokenIn).safeTransfer(swapRequest.pool, transferAmount);
//     }

//     function _takeAssetOut(
//         address _receiver,
//         uint256 fee,
//         uint256 amountOutAfterFee, 
//         address _tokenOut
//     ) internal {
//         vault.takeAssetOut(bytes32(0), _receiver, fee, amountOutAfterFee + fee, _tokenOut, PRICE_PRECISION);
//     }

//     function _fromTokenToUSD(address _token, uint256 _tokenAmount, uint256 _price) internal view returns (uint256) {
//         if (_tokenAmount == 0) {
//             return 0;
//         }

//         uint256 decimals = priceManager.tokenDecimals(_token);
//         require(decimals > 0, "Invalid decimals while converting from token to USD");
//         return (_tokenAmount * _price) / (10 ** decimals);
//     }

//     function _fromUSDToToken(address _token, uint256 _usdAmount, uint256 _price) internal view returns (uint256) {
//         if (_usdAmount == 0) {
//             return 0;
//         }
        
//         uint256 decimals = priceManager.tokenDecimals(_token);
//         require(decimals > 0, "Invalid decimals while converting from USD to token");
//         return (_usdAmount * (10 ** decimals)) / _price;
//     }

//     function _isFastExecute(address _indexToken) internal view returns (uint256, bool) {
//         (uint256 price, uint256 updatedAt, bool isFastPrice) = priceManager.getLatestSynchronizedPrice(_indexToken);
//         uint256 maxPriceUpdatedDelay = settingsManager.maxPriceUpdatedDelay();
//         bool isFastExecute = isFastPrice && price > 0 
//             && maxPriceUpdatedDelay > 0  && block.timestamp - updatedAt <= maxPriceUpdatedDelay;

//         return (price, isFastExecute);
//     }

//     function _transferFrom(address _token, address _account, uint256 _amount) internal {
//         IERC20(_token).safeTransferFrom(_account, address(this), _amount);
//     }

//     function _transferTo(address _token, uint256 _amount, address _receiver) internal {
//         IERC20(_token).safeTransfer(_receiver, _amount);
//     }

//     function _getLastPath(address[] memory _path) internal pure returns (address) {
//         return _path[_path.length - 1];
//     }
// }