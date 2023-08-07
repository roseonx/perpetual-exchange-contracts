const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	//
	functionName = "initialize";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address,address)");
	encodeParams = abi.encodeParameters(["address", "address"], [contractMap.get("PriceManager"), contractMap.get("SettingsManager")]);
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
	functionName = "setVaultUtils";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
	encodeParams = abi.encodeParameters(["address"], [contractMap.get("VaultUtils")]);
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
	functionName = "setPositionRouter";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
	encodeParams = abi.encodeParameters(["address"], [contractMap.get("PositionRouter")]);
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

	functionName = "updateBalance";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
	encodeParams = abi.encodeParameters(["address"], [contractMap.get("RUSD")]);
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
	functionName = "addOrRemoveCollateralToken";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
	encodeParams = abi.encodeParameters(["address", "bool"], [contractMap.get("StableUSDC"), true]);
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

	let addresses = [
		contractMap.get("TradingWETH"),
		contractMap.get("TradingBTC"),
		contractMap.get("TradingMATIC"),
		contractMap.get("TradingBNB"),
		contractMap.get("TradingARB")
	];

	for (let address of addresses) {
		functionName = "addOrRemoveTradingToken";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
		encodeParams = abi.encodeParameters(["address", "bool"], [address, true]);
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

	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};