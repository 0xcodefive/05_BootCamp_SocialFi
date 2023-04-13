require("dotenv").config();
const { ethers } = require("ethers");
const { ABI, CONTRACT_ADDRESS } = require("./constantsForNode");
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const BNBT_RPC_URL = process.env.BNBT_RPC_URL;

const provider = new ethers.providers.JsonRpcProvider(BNBT_RPC_URL);
const signer = new ethers.Wallet(PRIVATE_KEY, provider);
const addressSigner = signer.address;
console.error(`Address signer: ${addressSigner}`);

const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, signer);
const WAIT_BLOCK_CONFIRMATIONS = 2;

async function safeMint(address) {
  const price = await contract.priceToMint(address);
  const tx = await contract.safeMint({ value: price });
  console.log(`safeMint hash: ${tx.hash}`);
  await signer.provider.waitForTransaction(tx.hash, WAIT_BLOCK_CONFIRMATIONS);
}

async function donateEth(author, valueFromEther) {
  const tx = await contract.donateEth(author, {
    value: ethers.utils.parseEther(valueFromEther),
  });
  console.log(`donate hash: ${tx.hash}`);
}

async function donateToken(tokenAddress, tokenAmountFromEther, author) {
  const tx = await contract.donateToken(
    tokenAddress,
    ethers.utils.parseEther(tokenAmountFromEther),
    author
  );
  console.log(`donateToken hash: ${tx.hash}`);
}

async function getFirstUsersToken(address) {
  const balance = await contract.balanceOf(address);
  if (balance > 0) {
    const totalSupply = await contract.totalSupply();
    for (let tokenId = 0; tokenId < totalSupply; tokenId++) {
      const owner = await contract.ownerOf(tokenId);
      if (owner.toLowerCase() === address.toLowerCase()) {
        return tokenId;
      }
    }
  }
  return undefined;
}

async function main() {
  let usersToken = await getFirstUsersToken(addressSigner);
  console.error(`User token frst time: ${usersToken}`);
  if (usersToken === undefined) {
    await safeMint(addressSigner);
  }
  usersToken = await getFirstUsersToken(addressSigner);
  console.error(`User token scnd time: ${usersToken}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
