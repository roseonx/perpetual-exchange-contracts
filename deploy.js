const hre = require("hardhat");

const args = process.argv;
let contractName = args[2];
console.log("contractName", contractName);
let contractArgs = args.length == 4 && args[3].includes(",") ? args[3].split(",") : [args[3]];
console.log("contractArgs", contractArgs);
console.log("contractArgs.length", contractArgs.length);

async function deploy() {
	let Contract;
	let contract;
	let contractAddress;
	let contractNameArr = contractName.split("_");
	let exactContractName = contractNameArr[0];

	if (exactContractName === "TradingWETH" 
		|| exactContractName === "TradingBTC" 
		|| exactContractName === "TradingMATIC" 
		|| exactContractName === "TradingBNB" 
		|| exactContractName === "TradingARB" 
		|| exactContractName === "StableUSDC" 
		|| exactContractName === "CollateralBLUR") {
		exactContractName = "TestERC20";
	}

	let GAS_LIMIT = 500_000_000; //Goerli testnet crazy gasLimit
	let GAS_PRICE = 1_500_000_000;
	Contract = await hre.ethers.getContractFactory(exactContractName);

	if (GAS_LIMIT > 0) {
		contract = await (contractArgs.length == 1 && contractArgs[0] === "" ? Contract.deploy({gasLimit: GAS_LIMIT, gasPrice: GAS_PRICE}) 
			: Contract.deploy(...contractArgs, {gasLimit: GAS_LIMIT, gasPrice: GAS_PRICE}));
	} else {
		contract = await (contractArgs.length == 1 && contractArgs[0] === "" ? Contract.deploy() : Contract.deploy(...contractArgs));
	}

	await contract.deployed();
	contractAddress = contract.address;
	console.log(`${contractName} deployed ${contractAddress} success`);
}

deploy().catch((error) => {
	console.log(`Deploy contract ${contractName} got error ${error}`);
	process.exitCode = 1;
});
