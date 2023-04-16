# SocialFi

Our web3 application provides an opportunity for bloggers and influencers to monetize their channel on social networks through the creation of closed sessions for training, streams, and other events, as well as to receive donations from subscribers.

All payments are made through smart contracts, which guarantees security and transparency. Each channel is an NFT, which ensures ownership and earnings. To motivate the development of the channel, we have added a step-by-step reduction of the commission for our services depending on the profitability of the channel.

Our service allows authors to earn on donations and sessions, payment of which can be made in the base coin of the blockchain or in tokens specified by the author. Authors can create sessions by setting a price, a token for payment, the end time of registration, the maximum number of participants and the type of session.

Whitelists allow authors to automatically buy participation in a session without moderation, and blacklists allow you to block access to a session for certain users. All sessions have a structure with addresses of participants that can be confirmed, not confirmed or rejected by the author. In the case of a moderated session, funds are blocked on the contract until the author makes a decision on each participant.

Users can cancel the entry and refund the funds if their application has not yet been accepted by the author.

After the session ends, participants can leave likes or dislikes, and the rating of each session is stored in the blockchain and is not subject to censorship or falsification.

Each donation and session record generates an event in the blockchain, which allows embedding these events into various services.

##

## Install

```shell
npm init
npm install --save-dev "hardhat@^2.13.0" "@nomicfoundation/hardhat-toolbox@^2.0.0" @openzeppelin/contracts @uniswap/v2-periphery
npm install --save-dev solidity-coverage hardhat-gas-reporter hardhat-contract-sizer
npm install dotenv --save

npx hardhat
npx hardhat test

npx hardhat run scripts/deploy.js --network bnb_testnet
```

## Other information

uniswapRouterAddress in BSC testnet: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1

uniswapRouterAddress in Mainnet Eth: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D

levelsCount: 5

baseURI: ipfs://QmSPdJyCiJCbJ2sWnomh6gHqkT2w1FSnp7ZnXxk3itvc14/

## Deployed result for SocialFi

```
owner address: 0xc0DE5BCbE4dd5A6E1F7C827B898330d69CcEF216

Contract deployed to 0x3dadF47D608cD37faC48590381B73CF5AC35684f on bnb_testnet

Successfully verified contract SocialFi on Etherscan:
https://testnet.bscscan.com/address/0x3dadF47D608cD37faC48590381B73CF5AC35684f#code
```

## Deployed result for PrivateDonation

const param1 = "0x3dadF47D608cD37faC48590381B73CF5AC35684f";

const param2 = "0xc0dec91957A1839E899f0318440192D7E618c26C";

const param3 = ethers.utils.parseEther("0.1");

const param4 = 1500;

```
owner address: 0xc0DE5BCbE4dd5A6E1F7C827B898330d69CcEF216

Contract deployed to 0x9D78fF872850cd765eCAd98dcF5C8B51AD5f7d11 on bnb_testnet

Successfully verified contract PrivateDonation on Etherscan:
https://testnet.bscscan.com/address/0x9D78fF872850cd765eCAd98dcF5C8B51AD5f7d11#code
```

## TO DO

Disable **uniswapRouterAddress** verification for addresses not included in DEX
