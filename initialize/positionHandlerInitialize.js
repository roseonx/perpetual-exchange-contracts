const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	//
	functionName = "initialize";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address,address,address,address,address)");
	encodeParams = abi.encodeParameters(["address", "address", "address", "address", "address"], 
		[
			contractMap.get("PriceManager"), 
			contractMap.get("SettingsManager"),
			contractMap.get("TriggerOrderManager"),
			contractMap.get("Vault"),
			contractMap.get("VaultUtils"),
		]
	);
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

	//Set executor
	functionName = "setExecutor";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
	encodeParams = abi.encodeParameters(["address", "bool"], ["0x176b6fb460b1b5ff3d5447a0bb5119b08bd8ae8c", true]);
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