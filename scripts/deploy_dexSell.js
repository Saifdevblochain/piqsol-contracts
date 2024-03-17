const { ethers } = require("hardhat");

const { run } = require("hardhat");

async function verify(address, constructorArguments) {
    console.log(`verify  ${address} with arguments ${constructorArguments.join(',')}`)
    await run("verify:verify", {
        address,
        constructorArguments
    })
}

async function main() {

    let PQLTokenAddress = ''

    const DexSell = await ethers.getContractFactory(
        "DexSell"
    );
    console.log("Deploying DexSell...");

    const contract = await upgrades.deployProxy(DexSell, [PQLTokenAddress], {
        initializer: "initialize",
        kind: "UUPS",
    });
    await contract.deployed();

    console.log("DexSell deployed to:", contract.target);

    await new Promise(resolve => setTimeout(resolve, 15000));
    verify(contract.target, [])
}

main();
