const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	//FastPriceFeed.
	let assets = [
		"WETH",
		"BTC",
		"MATIC",
		"BNB",
		"ARB",
		"USDC",
		"BLUR",
	];

	let filterAssetMap = new Map();
	console.log("contractMap.keys()", contractMap.keys());

	contractMap.forEach((value, key, map) => {
		for (let asset of assets) {
			if (key.includes(asset) && key.split("_").length == 1) {
				filterAssetMap.set(asset, key);
			}
		}
	});

	console.log("filterAssetMap", filterAssetMap);

	for (let asset of assets) {
		try {
			functionName = "grantAccess";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
			encodeParams = abi.encodeParameters(["address", "bool"], 
				[
					contractMap.get("VaultPriceFeed"), 
					true
				]
			);
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: contractMap.get("FastPriceFeed_" + asset),
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
			console.log(`Signed ${functionName} ff ${asset}`);
			console.log(signed);
		} catch (err) {
			//Ignored
			console.log(`Error on ${functionName} ff ${asset} err ${err}`);
		}
	}	

	try {
		functionName = "setSupportFastPrice";
		functionSignature = abi.encodeFunctionSignature(functionName + "(bool)");
		encodeParams = abi.encodeParameters(["bool"], 
			[true]
		);
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get("VaultPriceFeed"),
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

	for (let asset of assets) {
		//
		try {
			functionName = "setTokenAggregator";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,address)");
			encodeParams = abi.encodeParameters(["address", "address"], 
				[
					contractMap.get(filterAssetMap.get(asset)),
					contractMap.get("DummyChainlinkAggregator_" + asset)
				]
			);
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: contractMap.get("VaultPriceFeed"),
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

		//
		try {
			functionName = "setTokenConfig";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,address,uint256)");
			encodeParams = abi.encodeParameters(["address", "address", "uint256"], 
				[
					contractMap.get(filterAssetMap.get(asset)),
					contractMap.get("FastPriceFeed_" + asset),
					18
				]
			);
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: contractMap.get("VaultPriceFeed"),
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

	//SetVaultPriceFeed
	try {
		functionName = "setVaultPriceFeed";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
		encodeParams = abi.encodeParameters(["address"], 
			[
				contractMap.get("VaultPriceFeed")
			]
		);
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


	for (let asset of assets) {
		//
		try {
			functionName = "setTokenConfig";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256,uint256,bool)");
			encodeParams = abi.encodeParameters(["address", "uint256", "uint256", "bool"], 
				[
					contractMap.get(filterAssetMap.get(asset)),
					asset === "USDC" ? 6 : 18,
					asset === "USDC" ? 10001 : 500000,
					false
				]
			);
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
	}

	let latestPriceMap = new Map();
	latestPriceMap.set("WETH", "0x6C6B935B8BBD400000"); //2000 * 10^18
	latestPriceMap.set("USDC", "0xDE0B6B3A7640000"); //1 * 10^18
	latestPriceMap.set("BLUR", "0x6f05b59d3b20000"); //0.5 * 10^18
	latestPriceMap.set("BTC", "0x3af418202d954e00000"); //17400 * 10^18
	latestPriceMap.set("MATIC", "0xbef55718ad60000"); //0.86 * 10^18
	latestPriceMap.set("BNB", "0x111380cf0ef80c0000");  //315 * 10^18
	latestPriceMap.set("ARB", "0x10a741a462780000");  //1.2 * 10^18

	// for (let asset of assets) {
	// 	try {
	// 		functionName = "setLatestPrice";
	// 		functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256)");
	// 		encodeParams = abi.encodeParameters(["address", "uint256"], 
	// 			[
	// 				contractMap.get(filterAssetMap.get(asset)),
	// 				latestPriceMap.get(asset)
	// 			]
	// 		);
	// 		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// 		transaction = {
	// 			to: contractMap.get("VaultPriceFeed"),
	// 			value: 0,
	// 			gas: gasLimit,
	// 			gasPrice: gasPrice,
	// 			nonce: nonce,
	// 			chainId: chainId,
	// 			data: data
	// 		};
	// 		signed = await account.signTransaction(transaction);
	// 		resMap.set(contract + "_" + nonce + "_" + functionName, signed.rawTransaction);
	// 		nonce++;
	// 		console.log(`Signed ${functionName}`);
	// 		console.log(signed);
	// 	} catch (err) {
	// 		//Ignored
	// 		console.log(`Error on ${functionName} err ${err}`);
	// 	}
	// }
	
	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};