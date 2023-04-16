// SPDX-License-Identifier: MIT
/************************************************************\
*                                                            *
*      ██████╗ ██╗  ██╗ ██████╗ ██████╗ ██████╗ ███████╗     *
*     ██╔═████╗╚██╗██╔╝██╔════╝██╔═████╗██╔══██╗██╔════╝     *
*     ██║██╔██║ ╚███╔╝ ██║     ██║██╔██║██║  ██║█████╗       *
*     ████╔╝██║ ██╔██╗ ██║     ████╔╝██║██║  ██║██╔══╝       *
*     ╚██████╔╝██╔╝ ██╗╚██████╗╚██████╔╝██████╔╝███████╗     *
*      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝     *
*                                                            *
\************************************************************/                                                  

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface ISocialFi {
    function donateEth(uint256 author) external payable;
    function owner() external view returns (address);
}

contract PrivateDonation is Ownable {
    using SafeMath for uint256;
    
    address verifier;
    uint256 donationValue;
    uint256 public donationFee;
    uint256 blockedForWithdraw;
    mapping(bytes32 => bool) isClosed;
    mapping(bytes32 => uint256) hashIndex;
    mapping(uint256 => uint256) public lastRequestToClose;
    bytes32[] public hashes;
    address socialFiAddress;

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

    modifier onlyVerifier(){
        require(verifier == msg.sender, "Only verifier");
        _;
    }

    modifier timeDelay(uint256 tokenId){
        require(lastRequestToClose[tokenId] < block.timestamp, "Time delay");
        _;
    }

    event Received(address indexed sender, uint256 value);
    event SocialFiContractChanged(address oldAddress, address newAddress);

    constructor(address _socialFiAddress, address _verifier, uint256 _donationValue, uint256 _donationFee) {
        isActive = true;
        pushNewHash(0);
        setNftContract(_socialFiAddress);
        setVerifier(_verifier);
        setDonationValue(_donationValue);
        setDonationFee(_donationFee);
    }

    function setDonationValue(uint256 _donationValue) public onlyOwner{
        require(_donationValue >= 10**6, "Low value");
        require(address(this).balance == 0, "Contract has unclosed donations");
        donationValue = _donationValue;
    }

    function setDonationFee(uint256 _donationFee) public onlyOwner{
        require(_donationFee < 10000, "Fee too high");
        donationFee = _donationFee;
    }

    function setActivation(bool newStatus) public onlyOwner{
        require(isActive != newStatus, "Value does not match the expectation");
        isActive = newStatus;
    }

    function setVerifier(address _verifier) public onlyOwner{
        verifier = _verifier;
    }

    function setNftContract(address _address) public onlyOwner {
        require(IERC721(_address).supportsInterface(0x80ac58cd), "Specified address is not valid");
        require(address(this).balance == 0, "Contract has unclosed donations");
        emit SocialFiContractChanged(socialFiAddress, _address);
        socialFiAddress = _address;
    }

    function pushNewHash(bytes32 hash) private {
        hashIndex[hash] = hashes.length;
        hashes.push(hash);
    }

    function getDonationValue() public view returns(uint256){
        return donationValue + donationValue.mul(donationFee).div(10000);
    }

    function _hashUsed(bytes32 hash) private view returns(bool) {
        return hashIndex[hash] != 0;
    }

    function getPublicHash(bytes32 privateHash) public view returns(bytes32 profHash, uint256 nonce) {
        profHash = privateHash;
        for(nonce = 0; nonce < hashes.length; nonce++){
            profHash = _hashPair(privateHash, profHash);
            profHash = _hashPair(profHash, bytes32(nonce));
            if (!_hashUsed(profHash)){
                break;
            }
            if (isClosed[profHash]){
                nonce = 0;
                break;
            }
        }
    }

    function sendPrivateDonation(bytes32 publicHash) public onlyActive lock payable {
        require(!isClosed[publicHash], "This donation is closed");
        require(msg.value == getDonationValue(), "Value is incorrect");
        require(!_hashUsed(publicHash), "Hash was used, try next time");
        uint256 feeValue = donationValue.mul(donationFee).div(10000);
        address feeRecipient = ISocialFi(socialFiAddress).owner();
        (bool success, ) = feeRecipient.call{value: feeValue}("");
        require(success, "fail");
        pushNewHash(publicHash);
        blockedForWithdraw += donationValue;
    }

    function receiveDonation(bytes32 publicHash, uint256 tokenId, uint256 count, uint256 gasFee) public onlyVerifier timeDelay(tokenId) lock {
        require(!_hashUsed(publicHash), "Hash was used, try next time");
        require(count > 4, "not enough");
        lastRequestToClose[tokenId] = block.timestamp + 3600;
        pushNewHash(publicHash);
        isClosed[publicHash] = true;
        (bool successFee, ) = verifier.call{value: gasFee}("");
        require(successFee, "fail");
        uint256 amount = count.mul(donationValue);
        ISocialFi(socialFiAddress).donateEth{value: amount.sub(gasFee)}(tokenId);
        blockedForWithdraw -= amount;
    }
    
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function withdraw() external onlyOwner lock {
        require(address(this).balance > blockedForWithdraw, "not enough");
        uint256 amount = address(this).balance - blockedForWithdraw;
        (bool success, ) = _msgSender().call{value: amount}("");
        require(success, "fail");
    }

    function withdrawTokens(address _address) external onlyOwner lock {
        IERC20 token = IERC20(_address);
        uint256 tokenBalance = token.balanceOf(address(this));
        token.transfer(_msgSender(), tokenBalance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}