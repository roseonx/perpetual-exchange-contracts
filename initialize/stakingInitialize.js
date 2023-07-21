const initialize =	async function inittialize(resMap, contractMap, contract, web3, abi, account, nonce, gasPrice, gasLimit, chainId) {
	let functionName = "";
	let functionSignature = "";
	let encodeParams = "";
	let data = "";
	let transaction = {};
	let signed = {};

	let rewardMap = new Map();
	rewardMap.set(contractMap.get("ROSX"), "10000000000000000");
	rewardMap.set(contractMap.get("EROSX"), "20000000000000000");
	rewardMap.set(contractMap.get("StableUSDC"), "200");

	contract = "StakingDual";
	//
	for (let asset of rewardMap.keys()) {
		try {
			functionName = "addReward";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256)");
			encodeParams = abi.encodeParameters(["address", "uint256"], [asset, rewardMap.get(asset)]);
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
		} catch (err) {
			//Ignored
			console.log(`Error on ${functionName} ff ${asset} err ${err}`);
		}
	}

	rewardMap = new Map();
	rewardMap.set(contractMap.get("EROSX"), "20000000000000000");
	rewardMap.set(contractMap.get("StableUSDC"), "300");
	contract = "StakingROLP";
	//
	for (let asset of rewardMap.keys()) {
		//
		try {
			functionName = "addReward";
			functionSignature = abi.encodeFunctionSignature(functionName + "(address,uint256)");
			encodeParams = abi.encodeParameters(["address", "uint256"], [asset, rewardMap.get(asset)]);
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
		} catch (err) {
			//Ignored
			console.log(`Error on ${functionName} ff ${asset} err ${err}`);
		}
	}

	let stakes = ["StakingDual", "StakingROLP"];

	for (let stake of stakes) {
		//
		try {
			let start = Math.floor(Date.now() / 1000);
			let end = start + (30 * 24 * 60 * 60);
			functionName = "create";
			functionSignature = abi.encodeFunctionSignature(functionName + "(uint256,uint256)");
			encodeParams = abi.encodeParameters(["uint256", "uint256"], 
				[
					start, 
					end
				]
			);
			data = functionSignature + (encodeParams.length > 2 ? encodeParams.substring(2, encodeParams.length) : encodeParams);
			transaction = {
				to: contractMap.get(stake),
				value: 0,
				gas: gasLimit,
				gasPrice: gasPrice,
				nonce: nonce,
				chainId: chainId,
				data: data
			};
			signed = await account.signTransaction(transaction);
			resMap.set(stake + "_" + nonce + "_" + functionName, signed.rawTransaction);
			nonce++;
			console.log(`Signed ${functionName}`);
			console.log(signed);
		} catch (err) {
			//Ignored
			console.log(`Error on ${functionName} ff ${stake} err ${err}`);
		}
	}

	contract = "StakedTracker_sROSX";
	//
	try {
		functionName = "setMinter";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
		encodeParams = abi.encodeParameters(["address", "bool"], 
			[
				contractMap.get("StakingDual"), 
				true
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	contract = "StakingDual";
	//
	try {
		functionName = "setStakeTracker";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
		encodeParams = abi.encodeParameters(["address"], 
			[
				contractMap.get("StakedTracker_sROSX"), 
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	contract = "VestERosx";
	//
	try {
		functionName = "setLockRosxAddress";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
		encodeParams = abi.encodeParameters(["address"], 
			[
				contractMap.get("StakingDual"), 
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	contract = "EROSX";
	//
	try {
		functionName = "setMinter";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
		encodeParams = abi.encodeParameters(["address"], 
			[
				contractMap.get("VestERosx"), 
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	contract = "StakingDual";
	//
	try {
		functionName = "setPermission";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
		encodeParams = abi.encodeParameters(["address", "bool"], 
			[
				contractMap.get("VestERosx"),
				true
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	contract = "StakedTracker_sROLP";
	//
	try {
		functionName = "setMinter";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
		encodeParams = abi.encodeParameters(["address", "bool"], 
			[
				contractMap.get("StakingROLP"), 
				true
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	contract = "StakingROLP";
	//
	try {
		functionName = "setStakeTracker";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
		encodeParams = abi.encodeParameters(["address"], 
			[
				contractMap.get("StakedTracker_sROLP"), 
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	//
	try {
		functionName = "setStakingCompound";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address)");
		encodeParams = abi.encodeParameters(["address"], 
			[
				contractMap.get("StakingDual"), 
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	contract = "StakingDual";
	//
	try {
		functionName = "setPermission";
		functionSignature = abi.encodeFunctionSignature(functionName + "(address,bool)");
		encodeParams = abi.encodeParameters(["address", "bool"], 
			[
				contractMap.get("StakingROLP"),
				true
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
	} catch (err) {
		//Ignored
		console.log(`Error on ${functionName} ff ${asset} err ${err}`);
	}

	return {
		resMap: resMap,
		nonce: nonce
	}
};

module.exports = {initialize};