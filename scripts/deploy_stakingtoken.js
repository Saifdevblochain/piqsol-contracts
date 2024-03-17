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

    let _rewardsToken = ''
    let _stakingToken = ''

    const StakingContract = await ethers.getContractFactory(
        "StakingContract"
    );
    console.log("Deploying StakingContract...");

    const contract = await upgrades.deployProxy(StakingContract, [_rewardsToken, _stakingToken], {
        initializer: "initialize",
        kind: "UUPS",
    });
    await contract.deployed();

    console.log("StakingContract deployed to:", contract.target);

    await new Promise(resolve => setTimeout(resolve, 15000));
    verify(contract.target, [])
}

main();
