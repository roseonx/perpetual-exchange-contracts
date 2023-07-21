const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	/*
	PriceManager.
	*/
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
	//
	
	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};