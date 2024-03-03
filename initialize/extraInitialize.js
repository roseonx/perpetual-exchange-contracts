const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	//Set minter
	let addresses = [
		contractMap.get("RUSD"), 
		contractMap.get("ROLP"), 
		contractMap.get("eROSX")
	];

	for (let i = 0; i < addresses.length; i++) {
		functionName = "setMinter";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
		encodeParams = abi.encodeParameters(["address"], [contractMap.get("Vault")]);
		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
		transaction = {
			to: addresses[i],
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
	
	//Approve
	addresses = [
		contractMap.get("USDC.e"),
		contractMap.get("CollateralBLUR")
	];

	for (let i = 0; i < addresses.length; i++) {
		try {
			functionName = "approve";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256)");
			encodeParams = abi.encodeParameters(["address", "uint256"], [contractMap.get("Vault"), "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"]);
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: addresses[i],
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

	//Set settingsManager
	try {
		functionName = "setSettingsManager";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
		encodeParams = abi.encodeParameters(["address"], 
			[
				contractMap.get("SettingsManager")
			]);
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

	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};