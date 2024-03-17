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

    let _marketplaceOwner = ''
    let PQLTokenAddress = ''
    let _listingTax = ''
    let _buyitemTax = ''
    let _biditemTax = ''

    const PiqsolMarketplace = await ethers.getContractFactory(
        "PiqsolMarketplace"
    );
    console.log("Deploying ProjectStarterLaunchPadSeedSale...");

    const contract = await upgrades.deployProxy(PiqsolMarketplace, [_marketplaceOwner, PQLTokenAddress, _listingTax, _buyitemTax, _biditemTax], {
        initializer: "initialize",
        kind: "UUPS",
    });
    await contract.deployed();

    console.log("PiqsolMarketplace deployed to:", contract.target);

    await new Promise(resolve => setTimeout(resolve, 15000));
    verify(contract.target, [])
}

main();
