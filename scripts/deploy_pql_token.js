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

    let _toLiquidityPool = ''
    let _supply = ''


    const PQLtoken = await ethers.getContractFactory(
        "PQLtoken"
    );
    console.log("Deploying PQLtoken...");

    const contract = await upgrades.deployProxy(PQLtoken, [_toLiquidityPool, _supply], {
        initializer: "initialize",
        kind: "UUPS",
    });
    await contract.deployed();

    console.log("PQLtoken deployed to:", contract.target);

    await new Promise(resolve => setTimeout(resolve, 15000));
    verify(contract.target, [])
}

main();
