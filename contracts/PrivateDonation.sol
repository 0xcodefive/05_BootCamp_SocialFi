// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract PrivateDonation is Ownable, ReentrancyGuard {
    uint256 donationValue;
    uint256 blockedForWithdraw;
    mapping(uint256 => bool) public isClosed;
    mapping(bytes32 => uint256) public hashIndex;
    bytes32[] public hashes;
    IERC721 nftContract;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "Donation: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    bool isActive;
    modifier onlyActive() {
        require(isActive, "Donation: NOT ACTIVE");
        _;
    }

    modifier onlyAuthor(uint256 author){
        require(nftContract.ownerOf(author) == msg.sender, "Only author");
        _;
    }

    event Received(address indexed sender, uint256 value);
    event NftContractChanged(address oldNFT, address newNFT);

    constructor(uint256 _donationValue) {
        isActive = true;
        pushNewHash(0);
        donationValue = _donationValue;
    }

    function setDonationValue(uint256 _donationValue) public onlyOwner{
        require(address(this).balance == 0, "Contract has unclosed donations");
        donationValue = _donationValue;
    }

    function setActivation(bool newStatus) public onlyOwner{
        require(isActive != newStatus, "Value does not match the expectation");
        isActive = newStatus;
    }

    function setNftContract(address _address) public onlyOwner {
        emit NftContractChanged(address(nftContract), _address);
        nftContract = IERC721(_address);
    }

    function pushNewHash(bytes32 hash) private {
        hashIndex[hash] = hashes.length;
        hashes.push(hash);
        blockedForWithdraw += donationValue;
    }

    function hashUsed(bytes32 hash) private view returns(bool) {
        return hashIndex[hash] != 0;
    }

    function getPublicHash(bytes32 privateHash) public view returns(bytes32[3] memory profHashes, uint256 nonce) {
        profHashes[2] = privateHash;
        profHashes[1] = privateHash;
        profHashes[0] = privateHash;
        for(nonce = 0; nonce < hashes.length; nonce++){
            profHashes[2] = profHashes[1];
            profHashes[1] = profHashes[0];
            profHashes[0] = _efficientHash(privateHash, bytes32(nonce));
            if (!hashUsed(profHashes[0])){
                 break;
            }
        }
    }

    function privateDonation(bytes32 publicHash) public onlyActive lock payable {
        require(msg.value == donationValue, "Value is incorrect");
        require(!hashUsed(publicHash), "Hash was used, try next time");
        pushNewHash(publicHash);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function withdraw() external onlyOwner nonReentrant {
        require(address(this).balance > blockedForWithdraw, "not enough");
        uint256 amount = address(this).balance - blockedForWithdraw;
        (bool success, ) = _msgSender().call{value: amount}("");
        require(success, "fail");
    }

    function withdrawTokens(address _address) external onlyOwner nonReentrant {
        IERC20 token = IERC20(_address);
        uint256 tokenBalance = token.balanceOf(address(this));
        token.transfer(_msgSender(), tokenBalance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}