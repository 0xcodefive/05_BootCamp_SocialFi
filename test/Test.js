const { ethers } = require("hardhat");
const { assert, expect } = require("chai");

describe("T0xC", function () {
  let factoryNft, nft, factory, contract, owner, user, recipient;
  beforeEach(async function () {
    [owner, user, recipient] = await ethers.getSigners();
    factoryNft = await ethers.getContractFactory("NFT0xC0de");
    nft = await factoryNft.deploy("none");
    factory = await ethers.getContractFactory("T0xC");
    contract = await factory.deploy(nft.address);
  });

  it("Should have correct name, symbol and decimal places", async function () {
    console.log(`Owner address: ${owner.address}`);
    console.log(`User address: ${user.address}`);
    console.log(`Contract address: ${contract.address}`);
    console.log(`NFT address: ${nft.address}`);

    expect(await contract.name()).to.equal("Token by 0xc0de");
    expect(await contract.symbol()).to.equal("T0xC");
    expect(await contract.decimals()).to.equal(18);
  });

  it("Should stake/unstake NFT and mint reward", async function () {
    await nft.connect(owner).approve(contract.address, 0);
    expect(await nft.getApproved(0)).to.equal(contract.address);

    const tokenId = 0;
    expect(await nft.balanceOf(owner.address)).to.equal(1);
    expect(await contract.balanceOf(owner.address)).to.equal(0);

    await contract.connect(owner).stake(tokenId);
    expect(await nft.ownerOf(tokenId)).to.equal(contract.address);
    expect(await contract._owners(tokenId)).to.equal(owner.address);

    await contract.connect(owner).unstake(tokenId);
    expect(await nft.ownerOf(tokenId)).to.equal(owner.address);
  });

  it("Should transfer tokens correctly", async function () {
    const tokenId = 0;
    await nft.connect(owner).approve(contract.address, 0);
    await contract.connect(owner).stake(tokenId);

    const balance = await contract.balanceOf(owner.address);
    await contract.connect(owner).transfer(user.address, balance);
    const fee = await contract.calculateFee(balance);
    expect(await contract.balanceOf(user.address)).to.equal(balance.sub(fee));
  });

  it("Should calculate burn fee correctly", async function () {
    expect(await contract.calculateFee(10000)).to.equal(1);
  });

  it("Should set new NFT collection address", async function () {
    const newAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    await contract.setNftCollectionAddress(newAddress);
    expect(await contract._nftCollection()).to.equal(newAddress);

    await contract.setNftCollectionAddress(nft.address);
    expect(await contract._nftCollection()).to.equal(nft.address);
  });

  it("Should withdraw tokens", async function () {
    const tokenId = 0;
    await nft.connect(owner).approve(contract.address, 0);
    await contract.connect(owner).stake(tokenId);
    const balance = await contract.balanceOf(owner.address);

    await contract.connect(owner).transfer(contract.address, balance);
    expect(await contract.balanceOf(contract.address)).to.equal(balance);
    expect(await contract.balanceOf(owner.address)).to.equal(0);

    await contract.connect(owner).withdrawTokens(contract.address);
    expect(await contract.balanceOf(contract.address)).to.equal(0);
    expect(await contract.balanceOf(owner.address)).to.equal(balance);
  });

  it("Should withdraw Ethers", async function () {
    await contract.connect(owner).withdraw();
    const contractAddress = contract.address;
    const balance = await ethers.provider.getBalance(contractAddress);
    assert.equal(balance, 0);
  });

  it("Should emit Received event on receiving Ether", async function() {
    const transaction = {
      to: contract.address,
      value: ethers.utils.parseEther("1.0")
    };
    await owner.sendTransaction(transaction);

    const events = await contract.queryFilter("Received");
    expect(events.length).to.equal(1);
    expect(events[0].args[0]).to.equal(owner.address);
    expect(events[0].args[1]).to.equal(transaction.value);
  });
});
