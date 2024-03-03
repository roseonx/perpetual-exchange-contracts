const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	//
	functionName = "finalInitialize";
	functionSignature = abi.encodeFunctionSignature(functionName + "(address,address,address,address)");
	encodeParams = abi.encodeParameters(["address","address","address","address"], 
		[
			contractMap.get("Vault"),
			contractMap.get("PositionRouter"),
			contractMap.get("PositionHandler"),
			contractMap.get("PositionKeeper")
		]);
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