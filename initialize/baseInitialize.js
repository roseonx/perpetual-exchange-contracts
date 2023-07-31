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
	latestPriceMap.set("WETH", "650C324C1AD0200000"); //1864 * 10^18
	latestPriceMap.set("USDC", "0xDE0B6B3A7640000"); //1 * 10^18
	latestPriceMap.set("BLUR", "0x429D069189E0000"); //0.3 * 10^18
	latestPriceMap.set("BTC", "0x639C6F6281FC4600000"); //29400 * 10^18
	latestPriceMap.set("MATIC", "0x9B6E64A8EC60000"); //0.7 * 10^18
	latestPriceMap.set("BNB", "0xD2C4D6C87E3EC0000");  //243 * 10^18
	latestPriceMap.set("ARB", "0x101925DAA3740000");  //1.16 * 10^18

	for (let asset of assets) {
		try {
			functionName = "setLatestPrice";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256)");
			encodeParams = abi.encodeParameters(["address", "uint256"], 
				[
					contractMap.get(filterAssetMap.get(asset)),
					latestPriceMap.get(asset)
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
	
	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};