const { ethers } = require("ethers");
import { ABI, CONTRACT_ADDRESS } from "./constants";

const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, signer);
const addressSigner = await signer.getAddress();
const WAIT_BLOCK_CONFIRMATIONS = 2;

async function safeMint() {
  const price = await contract.priceToMint(addressSigner);
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
