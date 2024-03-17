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

  let _marketplaceOwner = ""
  let PQLTokenAddress = ''
  let _mintingTax = ''
  let _buy_fnftTax = ''

  const PiqsolNFTs = await ethers.getContractFactory(
    "PiqsolNFTs"
  );
  console.log("Deploying PiqsolNFTs...");

  const contract = await upgrades.deployProxy(PiqsolNFTs, [_marketplaceOwner, PQLTokenAddress, _mintingTax, _buy_fnftTax], {
    initializer: "initialize",
    kind: "UUPS",
  });
  await contract.deployed();

  console.log("PiqsolNFTs deployed to:", contract.target);

  await new Promise(resolve => setTimeout(resolve, 15000));
  verify(contract.target, [])
}

main();
