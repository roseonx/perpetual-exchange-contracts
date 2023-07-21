const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	//
	functionName = "enableMarketOrder";
	functionSignature = abi.encodeFunctionSignature(functionName + "(bool)");
	encodeParams = abi.encodeParameters(["bool"], ["true"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setFeeManager";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
	encodeParams = abi.encodeParameters(["address"], ["0x31161583ecF54bDd3eE8eA173Ce02a995fAfC2DB"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	functionName = "setEnableStable";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
	encodeParams = abi.encodeParameters(["address", "bool"], [contractMap.get("StableUSDC"), "true"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setEnableCollateral";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
	encodeParams = abi.encodeParameters(["address", "bool"], [contractMap.get("CollateralBLUR"), "true"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setEnableStaking";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
	encodeParams = abi.encodeParameters(["address", "bool"], [contractMap.get("StableUSDC"), "true"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setEnableUnstaking";
	functionSignature = abi.encodeFunctionSignature(functionName + "(bool)");
	encodeParams = abi.encodeParameters(["bool"], ["true"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setMaxOpenInterestPerUser";
	functionSignature = abi.encodeFunctionSignature(functionName + "(uint256)");
	encodeParams = abi.encodeParameters(["uint256"], ["400000000000000000000000"]); //400_000 * 10**18
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	let bools = [true, false];
	//
	for (let b of bools) {
		functionName = "setMaxOpenInterestPerSide";
		functionSignature = abi.encodeFunctionSignature(functionName + "(bool,uint256)");
		encodeParams = abi.encodeParameters(["bool", "uint256"], [b, "4000000000000000000000000"]); //4_000_000 * 10**18
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get(contract),
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
	}

	let assets = [
		contractMap.get("TradingWETH"),
		contractMap.get("TradingBTC"),
		contractMap.get("TradingMATIC"),
		contractMap.get("TradingBNB"),
		contractMap.get("TradingARB")
	];

	for (let asset of assets) {
		functionName = "setLiquidateThreshold";
		functionSignature = abi.encodeFunctionSignature(functionName + "(uint256,address)");
		encodeParams = abi.encodeParameters(["uint256", "address"], ["99999", asset]);
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get(contract),
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

		functionName = "setEnableTradable";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
		encodeParams = abi.encodeParameters(["address", "bool"], [asset, "true"]);
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get(contract),
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

		functionName = "setMaxOpenInterestPerAsset";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256)");
		encodeParams = abi.encodeParameters(["address", "uint256"], [asset, "1000000000000000000000000"]); //1_000_000 * 10**18
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get(contract),
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

		functionName = "setBorrowFeeFactor";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256)");
		encodeParams = abi.encodeParameters(["address", "uint256"], [asset, "5"]);
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get(contract),
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

		
		for (let b of bools) {
			//
			functionName = "setMaxOpenInterestPerAssetPerSide";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool,uint256)");
			encodeParams = abi.encodeParameters(["address", "bool", "uint256"], [asset, b, "500000000000000000000000"]); //500_000 * 10**18
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: contractMap.get(contract),
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
		}

		//
		functionName = "setMarginFeeBasisPoints";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool,uint256)");
		encodeParams = abi.encodeParameters(["address", "bool", "uint256"], [asset, true, "100"]);
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get(contract),
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

		//
		functionName = "setMarginFeeBasisPoints";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool,uint256)");
		encodeParams = abi.encodeParameters(["address", "bool", "uint256"], [asset, false, "100"]);
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: contractMap.get(contract),
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
	}

	//
	functionName = "setMaxPriceUpdatedDelay";
	functionSignature = abi.encodeFunctionSignature(functionName + "(uint256)");
	encodeParams = abi.encodeParameters(["uint256"], [300]); //5 mins
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setVaultSettings";
	functionSignature = abi.encodeFunctionSignature(functionName + "(uint256,uint256)");
	encodeParams = abi.encodeParameters(["uint256", "uint256"], [0, 50000]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setReferEnabled";
	functionSignature = abi.encodeFunctionSignature(functionName + "(bool)");
	encodeParams = abi.encodeParameters(["bool"], ["true"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setPositionHandler";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
	encodeParams = abi.encodeParameters(["address"], [contractMap.get("PositionHandler")]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setPositionKeeper";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
	encodeParams = abi.encodeParameters(["address"], [contractMap.get("PositionKeeper")]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setTriggerGasFee";
	functionSignature = abi.encodeFunctionSignature(functionName + "(uint256)");
	encodeParams = abi.encodeParameters(["uint256"], ["1000000000000000"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//
	functionName = "setCloseDeltaTime";
	functionSignature = abi.encodeFunctionSignature(functionName + "(uint256)");
	encodeParams = abi.encodeParameters(["uint256"], ["60"]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	//setVault
	functionName = "setVault";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
	encodeParams = abi.encodeParameters(["address"], [contractMap.get("Vault")]);
	data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	transaction = {
		to: contractMap.get(contract),
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

	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};