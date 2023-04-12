const { ethers } = require("ethers");

const contract = new ethers.Contract(
    CONTRACT_ADDRESS,
    ABI,
    signer
  );

async function donateEth(author, valueFromEther) {
  const tx = await contract.donateEth(author, { value: ethers.utils.parseEther(valueFromEther) });
  console.log(`donate hash: ${tx.hash}`);
}

async function donateToken(tokenAddress, tokenAmountFromEther, author) {
  const tx = await contract.donateToken(tokenAddress, ethers.utils.parseEther(tokenAmountFromEther), author);
  console.log(`donate hash: ${tx.hash}`);
}