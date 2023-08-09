const fs = require('fs');
const { spawnSync } = require('node:child_process');
const os = require('os');

//MATIC_TEST
// const RPC = "https://polygon-mumbai.blockpi.network/v1/rpc/public";
// const CONTRACTS_PATH = "/home/lc/Documents/SetupMaticContracts.txt";

//BSC_TEST
// const RPC = "https://data-seed-prebsc-1-s1.binance.org:8545/";
// const CONTRACTS_PATH = "/home/lc/Documents/SetupBSCContracts.txt";

//ARBITRUM_GOERLI
const RPC = "https://goerli-rollup.arbitrum.io/rpc";
const CONTRACTS_PATH = "/home/lc/Documents/SetupArbitrumContracts.txt";

const PK = "xXx";

let latestPriceMap = new Map();
latestPriceMap.set("WETH", "0x6C6B935B8BBD400000"); //2000 * 10^18
latestPriceMap.set("USDC", "0xDE0B6B3A7640000"); //1 * 10^18
latestPriceMap.set("BLUR", "0x6f05b59d3b20000"); //0.5 * 10^18
latestPriceMap.set("BTC", "0x3af418202d954e00000"); //17400 * 10^18
latestPriceMap.set("MATIC", "0xbef55718ad60000"); //0.86 * 10^18
latestPriceMap.set("BNB", "0x111380cf0ef80c0000");  //315 * 10^18
latestPriceMap.set("ARB", "0x10a741a462780000");  //1.2 * 10^18


//Arbitrum
const GAS_PRICE = 1500_000_000;
const GAS_LIMIT = 100_000_000;

//BSC
// const GAS_PRICE = 10_000_000_000;
// const GAS_LIMIT = 10_000_000;


main();

async function main() {
	let contractMap = await readContracts();
	console.log("contractMap", contractMap);

	/*
	Should run each function instead of run all
	*/

	//Deploy and verify base
	//await baseDeployAndVerify(contractMap);

	//Deploy and verify main
	//await mainDeployAndVerify(contractMap);

	//Deploy staking
	//await stakingDeployAndVerify(contractMap);

	//Initiliaze
	//await initialize(contractMap);

	console.log("Price_Manager".toUpperCase() + "=" + contractMap.get("PriceManager"));
	console.log("Position_Keeper".toUpperCase() + "=" + contractMap.get("PositionKeeper"));
	console.log("Position_Handler".toUpperCase() + "=" + contractMap.get("PositionHandler"));
	console.log("Trigger_Order".toUpperCase() + "=" + contractMap.get("TriggerOrderManager"));
	console.log("Execute_Contract".toUpperCase() + "=" + contractMap.get("PositionRouter"));
	console.log("Vault_Utils".toUpperCase() + "=" + contractMap.get("VaultUtils"));
	console.log("SETTING_MANAGER".toUpperCase() + "=" + contractMap.get("SettingsManager"));
}

async function initialize(contractMap) {
	const Web3 = require('web3');
	const web3 = new Web3(RPC);
	const abi = web3.eth.abi;
	const ping = await web3.eth.net.getId();
	console.log("Ping", ping);
	let chainId = ping;

	let account = web3.eth.accounts.privateKeyToAccount(PK);
	console.log("account", account);

	nonce = await web3.eth.getTransactionCount(account.address, "latest");
	let contractsToInitialize = [
		"Base",
		"SettingsManager",
		"TriggerOrderManager",
		"VaultUtils",
		"Vault",
		"PositionHandler",
		"PositionKeeper",
		"PositionRouter",
		"Extra",
		"Post",
		"CreateTestPosition",
		"Staking"
	];

	let resMap = new Map();

	for (let contract of contractsToInitialize) {
		console.log("contract", contract);
		console.log("nonce", nonce);
		const res = await contractInittialize(resMap, contractMap, contract, web3, abi, account, nonce, chainId);
		resMap = res.resMap;
		nonce = res.nonce;
		console.log("--");
	}

	console.log("resMap", resMap);
	let broadcastResultSuccessCount = 0;

	for (let key of resMap.keys()) {
		try {
			const broadcastResult = await web3.eth.sendSignedTransaction(resMap.get(key));
			console.log("key", key);
			console.log("broadcastResult", broadcastResult);

			if (broadcastResult.transactionHash && broadcastResult.transactionIndex) {
				broadcastResultSuccessCount++;
			}
		} catch (err) {
			console.log(`broadcast with key ${key} got error ${err}`);
			//return;
		}
	}

	console.log("broadcastResultSuccessCount == resMap.size", broadcastResultSuccessCount === resMap.size);
}

async function contractInittialize(resMap, contractMap, contract, web3, abi, account, nonce, chainId) {
	let contractCamelCase = contract.substring(0,1).toLowerCase() + contract.substring(1);
	let contractInitialize = require("./initialize/" + contractCamelCase + "Initialize.js");
	resMap = await contractInitialize.initialize(resMap, contractMap, contract, web3, abi, account, nonce, GAS_PRICE, GAS_LIMIT, chainId);
	return resMap;
}

async function baseDeployAndVerify(contractMap) {
	let contractsToDeploy = [
		"ROLP",
		"RUSD",
		"TradingWETH",
		"TradingBTC",
		"TradingMATIC",
		"TradingBNB",
		"TradingARB",
		"StableUSDC",
		"CollateralBLUR",
		"DummyChainlinkAggregator_WETH",
		"DummyChainlinkAggregator_BTC",
		"DummyChainlinkAggregator_MATIC",
		"DummyChainlinkAggregator_BNB",
		"DummyChainlinkAggregator_ARB",
		"DummyChainlinkAggregator_USDC",
		"DummyChainlinkAggregator_BLUR",
		"FastPriceFeed_WETH",
		"FastPriceFeed_BTC",
		"FastPriceFeed_MATIC",
		"FastPriceFeed_BNB",
		"FastPriceFeed_ARB",
		"FastPriceFeed_USDC",
		"FastPriceFeed_BLUR",
		"VaultPriceFeed",
		"PriceManager"
	];

	await deploy(contractMap, contractsToDeploy);
	await writeLatestContract(contractMap);
}

async function mainDeployAndVerify(contractMap) {
	let contractsToDeploy = [
		"PositionHandler", 
		"Vault", 
		"SettingsManager",
		"TriggerOrderManager",
		"VaultUtils",
		"PositionKeeper",
		"PositionRouter"
	];

	await deploy(contractMap, contractsToDeploy);
	await writeLatestContract(contractMap);
}

async function stakingDeployAndVerify(contractMap) {
	let contractsToDeploy = [
		"StakingDual",
		"StakedTracker_sROSX",
		"VestERosx",
		"StakingROLP",
		"StakedTracker_sROLP"
	];

	await deploy(contractMap, contractsToDeploy);
	await writeLatestContract(contractMap);
}

function getContractArgs(contractMap, contract) {
	if (contract === "PositionHandler" || contract === "VaultPriceFeed" || contract === "ROLP" || contract == "RUSD") {
		return [];
	} else if (contract === "Vault") {
		return [contractMap.get("ROLP"), contractMap.get("RUSD")];
	} else if (contract === "SettingsManager") {
		return [contractMap.get("RUSD")];
	} else if (contract === "TriggerOrderManager") {
		return [contractMap.get("SettingsManager"), contractMap.get("PriceManager")];
	} else if (contract === "VaultUtils") {
		return [contractMap.get("PriceManager"), contractMap.get("SettingsManager")];
	} else if (contract === "PositionKeeper") {
		return [];
	} else if (contract === "PositionRouter") {
		return [
			contractMap.get("Vault"),
			contractMap.get("PositionHandler"),
			contractMap.get("PositionKeeper"),
			contractMap.get("SettingsManager"),
			contractMap.get("PriceManager"),
			contractMap.get("VaultUtils"),
			contractMap.get("TriggerOrderManager"),
			"0x0000000000000000000000000000000000000000"
		];
	} else if (contract === "SwapRouter") {
		return [contractMap.get("Vault"), contractMap.get("SettingsManager"), contractMap.get("PriceManager")];
	} else if (contract === "PriceManager") {
		return [contractMap.get("RUSD"), contractMap.get("VaultPriceFeed")];
	} else if (contract === "TradingWETH") {
		return ["WETH", 18];
	} else if (contract === "TradingBTC") {
		return ["BTC", 18];
	} else if (contract === "TradingMATIC") {
		return ["MATIC", 18];
	} else if (contract === "TradingBNB") {
		return ["BNB", 18]; 
	} else if (contract === "TradingARB") {
		return ["ARB", 18];
	} else if (contract === "StableUSDC") {
		return ["USDC", 6];
	} else if (contract === "CollateralBLUR") {
		return ["BLUR", 18];
	} else if (contract.includes("DummyChainlinkAggregator")) {
		let tmp = contract.split("_");

		if (tmp[1] === "WETH") {
			return [tmp[1], 18, latestPriceMap.get(tmp[1])];
		} else if (tmp[1] === "USDC") {
			return [tmp[1], 6, latestPriceMap.get(tmp[1])];
		} else if (tmp[1] === "BLUR") {
			return [tmp[1], 18, latestPriceMap.get(tmp[1])];
		} else if (tmp[1] === "BTC") {
			return [tmp[1], 18, latestPriceMap.get(tmp[1])];
		} else if (tmp[1] === "MATIC") {
			return [tmp[1], 18, latestPriceMap.get(tmp[1])];
		} else if (tmp[1] === "BNB") {
			return [tmp[1], 18, latestPriceMap.get(tmp[1])];
		} else if (tmp[1] === "ARB") {
			return [tmp[1], 18, latestPriceMap.get(tmp[1])];
		}
	} else if (contract.includes("FastPriceFeed")) {
		let tmp = contract.split("_");
		return tmp.length > 1 ? tmp[tmp.length - 1] : tmp[0];
	} else if (contract === "StakingDual") {
		return [contractMap.get("ROSX"), contractMap.get("EROSX")];
	} else if (contract.includes("StakedTracker")) {
		let tmp = contract.split("_");
		return ["Staked " + tmp[1].substring(1), tmp[1]];
	} else if (contract === "VestERosx") {
		return [contractMap.get("ROSX"), contractMap.get("EROSX")];
	} else if (contract === "StakingROLP") {
		return [contractMap.get("ROLP")];
	}
}

async function deploy(contractMap, contractsToDeploy) {
	contractsToDeploy.forEach(contract => {
		//Deploy
		console.log("--");
		console.log(`Prepare to deploy ${contract}`);
		let contractArgs = getContractArgs(contractMap, contract);
		console.log(`Input args ${contractArgs}`);
		let args = ["deploy.js", contract, contractArgs];
		let deploySpawn = spawnSync("node", args);
		let reg = /(.+)deployed\s(.+)\ssuccess$/;
		let deployRes = deploySpawn.stdout.toString();
		let deployArr = deployRes.split(os.EOL);
		console.log(`Output ${deployArr}`);

		if (deployArr.length > 0) {
			let contractAddress;

			for (let i = 0; i < deployArr.length; i++) {
				if (deployArr[i].includes("success")) {
					contractAddress = deployArr[i];
					break;
				}
			}

			if (contractAddress) {
				let groups = reg.exec(contractAddress);

				if (groups && groups.length == 3) {
					console.log(`${contract} has new address ${groups[2]}`)
					contractMap.set(contract, groups[2].toLowerCase());

					//Verify
					let verifyContractArgs = getContractArgs(contractMap, contract);
					let verifyArgs = ["hardhat", "verify", contractMap.get(contract), ...verifyContractArgs]
					let verifySpawn = spawnSync("npx", verifyArgs);
					let verifyRes = verifySpawn.stdout.toString();
					let verifyArr = verifyRes.split(os.EOL);
					console.log("verifyArr", verifyArr);
				}
			} else {
				console.log("Not found contract address for", contract);
			}
		} else {
			console.log(`Deploy ${contract} got error ${deploySpawn.stderr.toString()}`);
		}
	});
}

async function writeLatestContract(contractMap) {
	let content = "";
	let count = 0;

	for (let key of contractMap.keys()) {
		content += (key + ":" + contractMap.get(key) + (count < contractMap.size - 1 ? "\n" : ""));
		count += 1;
	}

	if (content) {
		console.log("Prepare to write latest contracts with content");
		console.log(content);
		console.log("--");
		await fs.writeFile(CONTRACTS_PATH, content, err => {
			if (err) {
				console.log("Write latest contracts err", err);
			}
		});
	}
}

async function readContracts() {
	const data = await fs.readFileSync(CONTRACTS_PATH, (err, data) => {
		return data.toString();
	});
	
	//console.log("data", data.toString());
	const contractMap = new Map();
	const textArr = data.toString().split(os.EOL);
	console.log("textArr.length", textArr.length);

	for (let i = 0; i < textArr.length; i++) {
		if (textArr[i] === "//") {
			break;
		} else if (textArr[i].trim() !== "") {
			//console.log("textArr[i].trim()", textArr[i].trim());
			let tmp = textArr[i].split(":");

			if (tmp.length == 2) {
				contractMap.set(tmp[0].trim(), tmp[1].trim());
				//console.log(`tmp[0].trim() ${tmp[0].trim()} tmp[1].trim() ${tmp[1].trim()}`);
			}
		}
	}

	return contractMap;
}

