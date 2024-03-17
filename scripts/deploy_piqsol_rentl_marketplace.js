const { ethers, upgrades } = require("hardhat");
require('@openzeppelin/hardhat-upgrades');
const { run } = require("hardhat");

async function verify(address, constructorArguments) {
    console.log(`verify  ${address} with arguments ${constructorArguments.join(',')}`)
    await run("verify:verify", {
        address,
        constructorArguments
    })
}

async function main() {

    let _marketplaceOwner = "0xe9c807275255ED206C681e5708A68Cc3E34f7eAe"

    const Piqsol_Renting = await ethers.getContractFactory(
        "PiqsolRentalMarketplace"
    );
    console.log("Deploying PiqsolRentalMarketplace...");

    const contract = await upgrades.deployBeacon(Piqsol_Renting, [_marketplaceOwner]);
    await contract.waitForDeployment();

    console.log("Piqsol_Renting deployed to:", contract.target);

    await new Promise(resolve => setTimeout(resolve, 15000));
    verify(contract.target, [])
}

main();
