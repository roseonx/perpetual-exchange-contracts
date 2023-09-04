const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	let addresses = [
		"0x176b6fb460b1b5ff3d5447a0bb5119b08bd8ae8c", //BE address
		account.address, //deploy address
	];

	for (let address of addresses) {
		functionName = "setExecutor";
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