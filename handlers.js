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

// Функция минта токенов. Автоматически проверяется минимальное требуемое количество для минта
async function safeMint(address) {
  const price = await contract.priceToMint(address);
  const tx = await contract.safeMint({ value: price });
  console.log(`safeMint hash: ${tx.hash}`);
  await signer.provider.waitForTransaction(tx.hash, WAIT_BLOCK_CONFIRMATIONS);
}

// Донат в Коине блокчейна ВНИМАНИЕ, функция принимает значение кратное 10**18, то есть единице Ether
async function donateEthByEther(author, valueFromEther) {
  const value = ethers.utils.parseEther(valueFromEther.toString());
  const tx = await contract.donateEth(author, { value: value });
  console.log(`donate hash: ${tx.hash}`);
}

// Донат в Токенах ВНИМАНИЕ, функция принимает значение кратное 10**18, то есть единице Ether
async function donateTokenByEther(tokenAddress, tokenAmountFromEther, author) {
  const value = ethers.utils.parseEther(tokenAmountFromEther.toString());
  const tx = await contract.donateToken(tokenAddress, value, author);
  console.log(`donateToken hash: ${tx.hash}`);
}

// Получение токенов пользователя, возвращает количество токенов и их id
async function getUsersTokens(address) {
  const balance = await contract.balanceOf(address);
  let tokens = [];
  if (balance > 0) {
    const totalSupply = await contract.totalSupply();
    for (let tokenId = 0; tokenId < totalSupply; tokenId++) {
      const owner = await contract.ownerOf(tokenId);
      if (owner.toLowerCase() === address.toLowerCase()) {
        tokens.push(tokenId);
      }
      if (tokens.length >= balance) {
        break;
      }
    }
  }
  return {
    balance: tokens.length,
    tokens: tokens,
  };
}

async function main() {
  let usersToken = await getUsersTokens(addressSigner);
  console.error(
    `User token frst time balance: ${usersToken.balance}, tokens: ${usersToken.tokens}`
  );
  if (usersToken.balance == 0) {
    await safeMint(addressSigner);
  }
  usersToken = await getUsersTokens(addressSigner);
  console.error(
    `User token scnd time balance: ${usersToken.balance}, tokens: ${usersToken.tokens}`
  );

  await donateEthByEther(usersToken.tokens[0], 0.0282828);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
