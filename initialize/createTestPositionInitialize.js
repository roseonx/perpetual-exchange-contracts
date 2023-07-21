const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	let tradingAssets = [
		contractMap.get("TradingWETH"),
		contractMap.get("TradingBTC"),
		contractMap.get("TradingBNB"),
		contractMap.get("TradingMATIC"),
		contractMap.get("TradingARB")
	];
	
	for (let asset of tradingAssets) {
		//SetFundingRateFactor
		try {
			functionName = "setFundingRateFactor";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256)");
			encodeParams = abi.encodeParameters(["address", "uint256"], 
				[
					asset,
					10
				]);
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: contractMap.get("SettingsManager"),
				value: 0,
				gas: gasLimit,
				gasPrice: gasPrice,
				nonce: nonce,
				chainId: chainId,
				data: data
			};
			signed = await account.signTransaction(transaction);
			resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
			nonce++;
			console.log(`Signed ${functionName}`);
			console.log(signed);
		} catch (err) {
			//Ignored
			console.log(`Error on ${functionName} err ${err}`);
		}
	}

	let assetPriceMap = new Map();
	assetPriceMap.set(contractMap.get("StableUSDC"), "1000000000000000000");
	//assetPriceMap.set(contractMap.get("TradingWETH"), "1940000000000000000000");
	// //assetPriceMap.set(contractMap.get("TradingBTC"), "30000000000000000000000");
	// // assetPriceMap.set(contractMap.get("TradingMATIC"), "800000000000000000");
	// // assetPriceMap.set(contractMap.get("TradingBNB"), "330000000000000000000");
	// // assetPriceMap.set(contractMap.get("TradingARB"), "1200000000000000000");
	// // assetPriceMap.set(contractMap.get("CollateralBLUR"), "400000000000000000");

	//Set latest prices
	try {
		functionName = "setLatestPrices";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address[],uint256[])");
		encodeParams = abi.encodeParameters(["address[]","uint256[]"], 
			[
				Array.from(assetPriceMap.keys()),
				Array.from(assetPriceMap.values())
			]);
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get("PriceManager"),
			value: 0,
			gas: gasLimit,
			gasPrice: gasPrice,
			nonce: nonce,
			chainId: chainId,
			data: data
		};
		signed = await account.signTransaction(transaction);
		resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
		nonce++;
		console.log(`Signed ${functionName}`);
		console.log(signed);
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} err ${err}`);
	}

	// //Stake 100
	// try {
	// 	functionName = "stake";
	// 	functionSignature = abi.encodeFunctionSignature(functionName + "(address,address,uint256)");
	// 	encodeParams = abi.encodeParameters(["address", "address", "uint256"], 
	// 		[
	// 			account.address, 
	// 			contractMap.get("StableUSDC"),
	// 			10000000
	// 		]);
	// 	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// 	transaction = {
	// 		to: contractMap.get("Vault"),
	// 		value: 0,
	// 		gas: gasLimit,
	// 		gasPrice: gasPrice,
	// 		nonce: nonce,
	// 		chainId: chainId,
	// 		data: data
	// 	};
	// 	signed = await account.signTransaction(transaction);
	// 	resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
	// 	nonce++;
	// 	console.log(`Signed ${functionName}`);
	// 	console.log(signed);
	// } catch (err) {
	// 	//Ignored
	// 	console.log(`Error on ${functionName} err ${err}`);
	// }

	let openAssetMap = new Map();

	for (let asset of assetPriceMap.keys()) {
		if (asset !== contractMap.get("StableUSDC") && asset !== contractMap.get("CollateralBLUR")) {
			openAssetMap.set(asset, assetPriceMap.get(asset));
		}
	}

	let TEST_COUNT = 0;
	
	//Create position market
	for (let asset of openAssetMap.keys()) {
		for (let i = 1; i <= TEST_COUNT; i++) {
			try {
				functionName = "openNewPosition";
				functionSignature = abi.encodeFunctionSignature(functionName + "(bool,uint8,uint256[],address[])");
				encodeParams = abi.encodeParameters(["bool", "uint8", "uint256[]", "address[]"], 
					[
						//i % 2 == 0 ? true : false, 
						true,
						"0",
						[
							assetPriceMap.get(asset),
							"50000",
							"0",
							"0",
							100000000 * i,
							200000000 * i,
							"1692497698",
							100000000 * i
						],
						[
							asset,
							contractMap.get("StableUSDC")
						]
					]);
				data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
				transaction = {
					to: contractMap.get("PositionRouter"),
					value: 0,
					gas: gasLimit,
					gasPrice: gasPrice,
					nonce: nonce,
					chainId: chainId,
					data: data
				};
				signed = await account.signTransaction(transaction);
				resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
				nonce++;
				console.log(`Signed ${functionName}`);
				console.log(signed);
			} catch (err) {
				//Ignored
				console.log(`Error on ${functionName} err ${err}`);
			}
		}
	}

	TEST_COUNT = 0;
	//Create position stop limit
	for (let i = 1; i <= TEST_COUNT; i++) {
		try {
			functionName = "openNewPosition";
			functionSignature = abi.encodeFunctionSignature(functionName + "(bool,uint8,uint256[],address[])");
			encodeParams = abi.encodeParameters(["bool", "uint8", "uint256[]", "address[]"], 
				[
					i % 2 == 0 ? true : false, 
					"3",
					[
						"0",
						"0",
						"1920000000000000000000",
						"2010000000000000000000",
						10000000 * i,
						20000000 * i,
						"0",
						10000000 * i,
					],
					[
						contractMap.get("TradingWETH"),
						contractMap.get("StableUSDC")
					]
				]);
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: contractMap.get("PositionRouter"),
				value: 1000000000000000,
				gas: gasLimit,
				gasPrice: gasPrice,
				nonce: nonce,
				chainId: chainId,
				data: data
			};
			signed = await account.signTransaction(transaction);
			resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
			nonce++;
			console.log(`Signed ${functionName}`);
			console.log(signed);
		} catch (err) {
			//Ignored
			console.log(`Error on ${functionName} err ${err}`);
		}
	}

	// //SetPriceAndExecute
	// try {
	// 	functionName = "setPriceAndExecute";
	// 	functionSignature = abi.encodeFunctionSignature(functionName + "(bytes32,uint256,uint256[])");
	// 	encodeParams = abi.encodeParameters(["bytes32", "uint256", "uint256[]"], 
	// 		[
	// 			"0xCD23761EC909EE1C47EB01EC0775EE0B0E06B02362C17C1CBE09633ADABC3469", 
	// 			"1",
	// 			[
	// 				"2007500000000000000000",
	// 				"1000000000000000000"
	// 			]
	// 		]);
	// 	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// 	transaction = {
	// 		to: contractMap.get("PositionRouter"),
	// 		value: 0,
	// 		gas: gasLimit,
	// 		gasPrice: gasPrice,
	// 		nonce: nonce,
	// 		chainId: chainId,
	// 		data: data
	// 	};
	// 	signed = await account.signTransaction(transaction);
	// 	resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
	// 	nonce++;
	// 	console.log(`Signed ${functionName}`);
	// 	console.log(signed);
	// } catch (err) {
	// 	//Ignored
	// 	console.log(`Error on ${functionName} err ${err}`);
	// }

	//Close position
	// try {
	// 	functionName = "closePosition";
	// 	functionSignature = abi.encodeFunctionSignature(functionName + "(bool,uint256,uint256[],address[])");
	// 	encodeParams = abi.encodeParameters(["bool", "uint256", "uint256[]", "address[]"], 
	// 		[
	// 			true, 
	// 			1,
	// 			[
	// 				"100000000000000000000000",
	// 				"1692497698"
	// 			],
	// 			[
	// 				contractMap.get("TradingWETH"),
	// 				contractMap.get("StableUSDC")
	// 			],
	// 		]);
	// 	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// 	transaction = {
	// 		to: contractMap.get("PositionRouter"),
	// 		value: 0,
	// 		gas: gasLimit,
	// 		gasPrice: gasPrice,
	// 		nonce: nonce,
	// 		chainId: chainId,
	// 		data: data
	// 	};
	// 	signed = await account.signTransaction(transaction);
	// 	resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
	// 	nonce++;
	// 	console.log(`Signed ${functionName}`);
	// 	console.log(signed);
	// } catch (err) {
	// 	//Ignored
	// 	console.log(`Error on ${functionName} err ${err}`);
	// }

	// //Update trigger orders
	// // try {
	// // 	functionName = "updateTriggerOrders";
	// // 	functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool,uint256,uint256[],uint256[],uint256[],uint256[],uint256[],uint256[])");
	// // 	encodeParams = abi.encodeParameters(["address", "bool", "uint256", "uint256[]", "uint256[]", "uint256[]", "uint256[]", "uint256[]", "uint256[]"], 
	// // 		[
	// // 			"0xee01c0cd76354c383b8c7b4e65ea88d00b06f36f", 
	// // 			true,
	// // 			5,
	// // 			["1879000000000000000000"],
	// // 			[],
	// // 			["100000"],
	// // 			[],
	// // 			["0"],
	// // 			[]
	// // 		]);
	// // 	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// // 	transaction = {
	// // 		to: contractMap.get("TriggerOrderManager"),
	// // 		value: 1000000000000000,
	// // 		gas: gasLimit,
	// // 		gasPrice: gasPrice,
	// // 		nonce: nonce,
	// // 		chainId: chainId,
	// // 		data: data
	// // 	};
	// // 	signed = await account.signTransaction(transaction);
	// // 	resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
	// // 	nonce++;
	// // 	console.log(`Signed ${functionName}`);
	// // 	console.log(signed);
	// // } catch (err) {
	// // 	//Ignored
	// // 	console.log(`Error on ${functionName} err ${err}`);
	// // }

	//Add position
	// try {
	// 	functionName = "addPosition";
	// 	functionSignature = abi.encodeFunctionSignature(functionName + "(bool,uint256,uint256[],address[])");
	// 	encodeParams = abi.encodeParameters(["bool", "uint256", "uint256[]", "address[]"], 
	// 		[
	// 			true,
	// 			0,
	// 			[100000000,200000000,1692497698,100000000],
	// 			["0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f","0x874A0269BBE3fA8b8ebb2BE15DAc2142843EeeeB"],
	// 		]);
	// 	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// 	transaction = {
	// 		to: contractMap.get("PositionRouter"),
	// 		value: 1000000000000000,
	// 		gas: gasLimit,
	// 		gasPrice: gasPrice,
	// 		nonce: nonce,
	// 		chainId: chainId,
	// 		data: data
	// 	};
	// 	signed = await account.signTransaction(transaction);
	// 	resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
	// 	nonce++;
	// 	console.log(`Signed ${functionName}`);
	// 	console.log(signed);
	// } catch (err) {
	// 	//Ignored
	// 	console.log(`Error on ${functionName} err ${err}`);
	// }

	// //Revert execute
	// try {
	// 	functionName = "revertExecution";
	// 	functionSignature = abi.encodeFunctionSignature(functionName + "(bytes32,uint256,address[],uint256[],string)");
	// 	encodeParams = abi.encodeParameters(["bytes32", "uint256", "address[]", "uint256[]", "string"], 
	// 		[
	// 			"0xCD23761EC909EE1C47EB01EC0775EE0B0E06B02362C17C1CBE09633ADABC3469", 
	// 			"7",
	// 			["0xee01c0cd76354c383b8c7b4e65ea88d00b06f36f","0x874a0269bbe3fa8b8ebb2be15dac2142843eeeeb"],
	// 			["1825000000000000000000","1000000000000000000"],
	// 			"Test"
	// 		]);
	// 	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// 	transaction = {
	// 		to: contractMap.get("PositionRouter"),
	// 		value: 0,
	// 		gas: gasLimit,
	// 		gasPrice: gasPrice,
	// 		nonce: nonce,
	// 		chainId: chainId,
	// 		data: data
	// 	};
	// 	signed = await account.signTransaction(transaction);
	// 	resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
	// 	nonce++;
	// 	console.log(`Signed ${functionName}`);
	// 	console.log(signed);
	// } catch (err) {
	// 	//Ignored
	// 	console.log(`Error on ${functionName} err ${err}`);
	// }

	// //Set price and execute in batch
	// try {
	// 	functionName = "setPriceAndExecuteInBatch";
	// 	functionSignature = abi.encodeFunctionSignature(functionName + "(address[],uint256[],bytes32[],uint256[])");
	// 	encodeParams = abi.encodeParameters(["address[]", "uint256[]", "bytes32[]", "uint256[]"], 
	// 		[
	// 			["0xee01c0cd76354c383b8c7b4e65ea88d00b06f36f","0x874a0269bbe3fa8b8ebb2be15dac2142843eeeeb"],
	// 			["1842982813330000000000","999733330000000000"],
	// 			["0x93817FB66B4521C56A6C76C9EF77F401004B68EF16C3F18CCEB58E28127BA5BE"],
	// 			[2]
	// 		]);
	// 	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// 	transaction = {
	// 		to: contractMap.get("PositionHandler"),
	// 		value: 0,
	// 		gas: gasLimit,
	// 		gasPrice: gasPrice,
	// 		nonce: nonce,
	// 		chainId: chainId,
	// 		data: data
	// 	};
	// 	signed = await account.signTransaction(transaction);
	// 	resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
	// 	nonce++;
	// 	console.log(`Signed ${functionName}`);
	// 	console.log(signed);
	// } catch (err) {
	// 	//Ignored
	// 	console.log(`Error on ${functionName} err ${err}`);
	// }

	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};