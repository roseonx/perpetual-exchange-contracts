const fs = require('fs');
const os = require('os');

const loadContracts = async function fn(PATH) {
	const data = await fs.readFileSync(PATH, (err, data) => {
		return data.toString();
	});
	
	const contractMap = new Map();
	const contracts = data.toString().split(os.EOL);
	console.log("Total contracts", contracts.length);

	for (let i = 0; i < contracts.length; i++) {
		if (contracts[i] === "//") {
			break;
		} else if (contracts[i].trim() !== "") {
			let tmp = contracts[i].split(":");

			if (tmp.length == 2) {
				let contractName = tmp[0].trim();
				let contractAddress = tmp[1].trim().toLowerCase();
				contractMap.set(contractName, contractAddress);
				//console.log(`${contractName}:${contractAddress}`);
			}
		}
	}

	return contractMap;
}

const initialize = async function fn(resMap, contractMap, contract, web3, account, nonce, chainId, GAS_PRICE, GAS_LIMIT) {
	let contractCamelCase = contract.substring(0,1).toLowerCase() + contract.substring(1);

	try {
		const contractName = contractCamelCase + "Initialize.js";
		console.log("contractName", contractName)
		let contractInitialize = require("./initialize/proxy/" + contractName);
		return await contractInitialize.initialize(resMap, contractMap, contract, web3, web3.eth.abi, account, nonce, GAS_PRICE, GAS_LIMIT, chainId);
	} catch (e) {
		//Few contract not need initialize, can ignore if module not found
		if (e.code && e.code === 'MODULE_NOT_FOUND') {
			return {
				resMap: resMap,
				nonce: nonce
			}
		} else {
			throw e;
		}
	}
}

function getContractArgs(contractMap, contract) {
	if (contract === "PositionHandler") {
		return [
			contractMap.get("PriceManager"),
			contractMap.get("SettingsManager")
		];
	} else if (contract === "PositionKeeper") {
		return [
			contractMap.get("PriceManager"),
			contractMap.get("PositionHandler")
		];
	} else if (contract === "PositionRouter") {
		return [
			contractMap.get("PriceManager"),
			contractMap.get("SettingsManager"),
			contractMap.get("PositionHandler"),
			contractMap.get("PositionKeeper"),
			contractMap.get("Vault"),
			contractMap.get("VaultUtils"),
			contractMap.get("TriggerOrderManager")
		];
	} else if (contract === "SettingsManager") {
		return [
			contractMap.get("RUSD"),
		];
	} else if (contract === "TriggerOrderManager") {
		return [
			contractMap.get("PriceManager"),
			contractMap.get("SettingsManager"),
			contractMap.get("PositionHandler"),
			contractMap.get("PositionKeeper")
		];
	} else if (contract === "VaultUtils") {
		return [
			contractMap.get("PriceManager"),
			contractMap.get("SettingsManager")
		];
	} else if (contract === "Vault") {
		return [
			contractMap.get("ROLP"),
			contractMap.get("RUSD")
		];
	}
}

async function writeLatestContracts(contractMap, PATH) {
	let content = "";
	let count = 0;

	for (let key of contractMap.keys()) {
		content += (key + ":" + contractMap.get(key) + (count < contractMap.size - 1 ? "\n" : ""));
		count += 1;
	}

	if (content) {
		console.log("--");
		console.log("Prepare to write latest contracts with content");
		console.log(content);
		console.log("--");
		await fs.writeFile(PATH, content, err => {
			if (err) {
				console.log("Write latest contracts err", err);
			}
		});
	}
}

async function sleep(time) {
    return new Promise((resolve) => {
        setTimeout(resolve, time || 1000);
    });
}

module.exports = {loadContracts, initialize, getContractArgs, sleep, writeLatestContracts};