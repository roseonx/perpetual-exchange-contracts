const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	//Set token config
	let addressConfigMap = new Map();
	addressConfigMap.set(contractMap.get("TradingWETH"), {decimal: 18, leverage: 500000});
	addressConfigMap.set(contractMap.get("TradingBTC"), {decimal: 18, leverage: 500000});
	addressConfigMap.set(contractMap.get("TradingMATIC"), {decimal: 18, leverage: 500000});
	addressConfigMap.set(contractMap.get("TradingBNB"), {decimal: 18, leverage: 500000});
	addressConfigMap.set(contractMap.get("TradingARB"), {decimal: 18, leverage: 500000});
	addressConfigMap.set(contractMap.get("StableUSDC"), {decimal: 6, leverage: 10001});
	addressConfigMap.set(contractMap.get("CollateralBLUR"), {decimal: 18, leverage: 10001});

	// for (let address of addressConfigMap.keys()) {
	// 	try {
	// 		functionName = "setTokenConfig";
	// 		functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256,uint256,bool)");
	// 		encodeParams = abi.encodeParameters(["address", "uint256", "uint256", "bool"], 
	// 			[
	// 				address,
	// 				addressConfigMap.get(address).decimal,
	// 				addressConfigMap.get(address).leverage,
	// 				false
	// 			]
	// 		);
	// 		data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
	// 		transaction = {
	// 			to: contractMap.get("PriceManager"),
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

	//Grant access
	let addressMap = new Map();
	addressMap.set(account.address, contractMap.get("PriceManager"));
	addressMap.set("0x176b6fb460b1b5ff3d5447a0bb5119b08bd8ae8c", contractMap.get("PriceManager"));
	addressMap.set(contractMap.get("PositionHandler"), contractMap.get("PriceManager"));
	addressMap.set(contractMap.get("PriceManager"), contractMap.get("VaultPriceFeed"));

	for (let sender of addressMap.keys()) {
		try {
			functionName = "grantAccess";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
			encodeParams = abi.encodeParameters(["address", "bool"], 
				[
					sender,
					true
				]);
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: addressMap.get(sender),
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
	
	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};