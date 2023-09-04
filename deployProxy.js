//ARBITRUM_GOERLI
const RPC = "https://goerli-rollup.arbitrum.io/rpc";
const CONTRACTS_PATH = "/home/lc/Documents/SetupArbitrumContracts.txt";
const PK = "xXx";
const GAS_PRICE = 1500_000_000;
const GAS_LIMIT = 100_000_000;


const os = require('os');
const { spawnSync } = require('node:child_process');
const { ethers, upgrades } = require('hardhat');
const { Web3 } = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider(RPC));
const utils = require("./utils.js");

main();

async function main() {
	let contractMap = await utils.loadContracts(CONTRACTS_PATH);
	let contracts = [
		// "SettingsManager",
		// "Vault",
		// "VaultUtils",
		// "PositionHandler",
		// "PositionKeeper",
		// "TriggerOrderManager",
		// "PositionRouter"
	];

	const account = web3.eth.accounts.privateKeyToAccount(PK);
	let nonce = await web3.eth.getTransactionCount(account.address, "latest");
	const chainId = await web3.eth.net.getId();
	console.log(`Account ${account.address} nonce ${nonce} chainId ${chainId}`);

	//Should run seperately between deploy/verify and initialize
	//Deploy and verify
	// await deploy(contractMap, contracts);
	// await verify(contractMap, contracts);
	
	//Initialize
	//await initialize(contractMap, contracts, web3, account, nonce, chainId);

	//After all, write latest contracts
	await utils.writeLatestContracts(contractMap, CONTRACTS_PATH);
}

async function deploy(contractMap, deployingContracts) {
	for (let deployingContract of deployingContracts) {
		let proxyContractName = deployingContract + "V2";
		const Contract = await ethers.getContractFactory(proxyContractName, {kind: "uups"});

		const contract = await upgrades.deployProxy(
			Contract, 
			utils.getContractArgs(contractMap, deployingContract), 
			{
	   			initializer: "initialize",
	 		}
	 	);

		let deployedAddress = contract.target;
		console.log(`Contract ${deployingContract} deployed ${deployedAddress}`)
		
		if (deployedAddress.startsWith("0x")) {
			contractMap.set(deployingContract, deployedAddress);
		}
	}

	return contractMap;
}

async function verify(contractMap, contracts) {
	for (let contractName of contracts) {
		//Verify impl
		let contract = contractMap.get(contractName);
		let impl = await web3.eth.getStorageAt(contract, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", "latest");
		let implContract = "0x" + impl.substring(impl.length - 40, impl.length);
		contractMap.set(contractName + "_Impl", implContract);
		console.log(`Prepare to verify ${contractName} impl ${implContract}`);
		let verifyArgs = ["hardhat", "verify", implContract]
		let verifySpawn = spawnSync("npx", verifyArgs);
		let res = verifySpawn.stdout.toString();
		let tmpRes = res.split(os.EOL);
		console.log("Verify res", tmpRes);

		//Verify proxy
		let apiKey = "FSEZV9V7WN8HK2CPK98IFBNGXSCSCIJX8F";
		const axios = require("axios");
		let url = "https://api-goerli.arbiscan.io/api?module=contract&action=verifyproxycontract&apikey=" + apiKey;
		let {data} = await axios.post(
			url,
			{
				address:contract
			},
			{
				headers: {"content-type": "application/x-www-form-urlencoded"} 
			}
		);
		
		if (data && data.result) {
			console.log(`Waiting for ${contractName} ruid ${data.result}`);
			await utils.sleep(6000);

			url = "https://api-goerli.arbiscan.io/api?module=contract&action=checkproxyverification&guid=" + data.result + "&apikey=" + apiKey;
			res = await axios.post(url, {},
			{
				headers: {"content-type": "application/x-www-form-urlencoded"} 
			});
			console.log(`Result for ${data.result}: ${JSON.stringify(res.data)}`);
		}
	}
}

async function initialize(contractMap, contracts, web3, account, nonce, chainId) {
	let resMap = new Map();

	for (let contract of contracts) {
		console.log("contract", contract);
		console.log("nonce", nonce);
		const res = await utils.initialize(resMap, contractMap, contract, web3, account, nonce, chainId, GAS_PRICE, GAS_LIMIT);
		resMap = res.resMap;
		nonce = res.nonce;
		console.log("--");
	}

	console.log("resMap", resMap);
	let broadcastResultSuccessCount = 0;

	for (let key of resMap.keys()) {
		try {
			const broadcastResult = await web3.eth.sendSignedTransaction(resMap.get(key), 
			{
				checkRevertBeforeSending: false,
				options: {
					checkRevertBeforeSending: false
				}
			});
			console.log("key", key);
			console.log("broadcastResult", broadcastResult);

			if (broadcastResult.transactionHash && broadcastResult.transactionIndex) {
				broadcastResultSuccessCount++;
			}
		} catch (err) {
			console.log(`broadcast with key ${key} got error ${err}`);
			return;
		}
	}

	console.log("broadcastResultSuccessCount == resMap.size", broadcastResultSuccessCount === resMap.size);
}


