const hre = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();

  const Name = "PrivateDonation";
  const Contract = await hre.ethers.getContractFactory(Name);

  const param1 = "0x3dadF47D608cD37faC48590381B73CF5AC35684f";
  const param2 = "0xc0dec91957A1839E899f0318440192D7E618c26C";
  const param3 = ethers.utils.parseEther("0.1");
  const param4 = 1500;
  const result = await Contract.deploy(param1, param2, param3, param4);
  await result.deployed();

  console.log(`owner address: ${owner.address}`);
  console.log(`Deployed result address: ${result.address}`);

  const WAIT_BLOCK_CONFIRMATIONS = 6;
  await result.deployTransaction.wait(WAIT_BLOCK_CONFIRMATIONS);

  console.log(`Contract deployed to ${result.address} on ${network.name}`);

  console.log(`Verifying contract on Etherscan...`);

  await run(`verify:verify`, {
    address: result.address,
    constructorArguments: [param1, param2, param3, param4],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
