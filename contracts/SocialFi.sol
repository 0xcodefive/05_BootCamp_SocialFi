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
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract SocialFi is ERC721Enumerable, IERC2981, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Strings for uint256;

    uint8 public levels; // Количество уровней рейтинга авторов
    uint16 public royaltyFee; // Рояльти за продажу NFT
    uint256 public totalAmounts; // Общая сумма оплат в Eth, прошедшая через контракт, используется для определения рейтинга авторов
    uint256 publicSaleTokenPrice = 0.1 ether; // Цена создания нового NFT (нового канала)
    string public baseURI; // Базовая ссылка на папку с метаданными NFT
    mapping (uint256 => uint256) public authorsAmounts; // Сумма оплаты по каждому автору (каналу), прошедшая через контракт
    IUniswapV2Router02 public uniswapRouter; // Провайдер для перерасчета платы в токенах на Eth

    enum Types {
        notModerated,
        moderated
    }

    struct Participants {
        address[] confirmed;
        address[] notConfirmed;
        address[] rejected;
    }

    struct Session {
        address tokenAddress;
        uint256 price;
        uint256 expirationTime;
        uint256 maxParticipants;
        string name;
        Types typeOf;
        Participants participants;
    }

    mapping(uint256 => address) public managers; // Менеджер канала, который является валидатором на сессиях
    mapping(uint256 => address[]) public donateTokenAddressesByAuthor;
    mapping(uint256 => mapping(address => bool)) public whiteListByAuthor;
    mapping(uint256 => mapping(address => bool)) public blackListByAuthor;
    mapping(uint256 => Session[]) public sessionByAuthor;

    mapping(address => uint256) internal blockedForWithdraw;

    event Received(address indexed sender, uint256 value);
    event NewSessionCreated(uint256 indexed author, string name, address token, uint256 price, uint256 expirationTime, uint256 maxParticipants, Types typeOf);
    event Donate(address indexed sender, address indexed token, uint256 value, uint256 indexed author);
    event PurchaseIsAwaitingConfirmation(address indexed participant, uint256 indexed author, uint256 indexed sessionId);
    event PurchaseConfirmed(address indexed participant, uint256 indexed author, uint256 indexed sessionId);
    event PurchaseRejected(address indexed participant, uint256 indexed author, uint256 indexed sessionId);
    event PurchaseCanceled(address indexed participant, uint256 indexed author, uint256 indexed sessionId);

    modifier supportsERC20(address _address){
        require(
            _address == address(0) || IERC20(_address).totalSupply() > 0,
            "Token does not support ERC20 interface"
        );
        _;
    }

    modifier onlyAuthor(uint256 author){
        require(ownerOf(author) == msg.sender || managers[author] == msg.sender , "You don't have enough rights");
        _;
    }
    
    modifier sessionIsOpenForSender(uint256 author, uint256 sessionId){
        require(!blackListByAuthor[author][msg.sender], "You are blacklisted by the author");
        Session memory session = sessionByAuthor[author][sessionId];
        require(session.expirationTime > block.timestamp && session.participants.confirmed.length >= session.maxParticipants, "Session is closed");
        Participants memory participants = session.participants;
        require(!isAddressExist(msg.sender, participants.rejected), "You are denied this session");
        require(!isAddressExist(msg.sender, participants.notConfirmed), "Expect a decision on your candidacy");
        require(!isAddressExist(msg.sender, participants.confirmed), "You are already on the list of participants");
        _;
    }

    constructor(address _uniswapRouterAddress, uint8 _levelsCount, string memory _baseURI) ERC721("SocialFi by 0xc0de", "SoFi") {
        uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
        levels = _levelsCount;
        baseURI = _baseURI;
        royaltyFee = 1000;
    }

    /***************Common interfaces BGN***************/
    function setBaseURI(uint8 _levelsCount, string memory _baseURI) external onlyOwner {
        levels = _levelsCount;
        baseURI = _baseURI;
    }

    function setPublicSaleTokenPrice(uint256 _newPrice) external onlyOwner {
        publicSaleTokenPrice = _newPrice;
    }

    function setNewRouter(address _uniswapRouterAddress) external onlyOwner {
        uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
    }

    function safeMint() public nonReentrant payable {
        uint256 _balanceOf = balanceOf(msg.sender);
        require(publicSaleTokenPrice * (2 ** _balanceOf) <= msg.value, "Ether value sent is not correct");
        uint256 nextIndex = totalSupply();
        managers[nextIndex] = msg.sender;
        _safeMint(msg.sender, nextIndex);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        uint256 thisLevel = (10 ** levels) * authorsAmounts[tokenId] / (totalAmounts + 1);
        uint256 uriNumber = myLog10(thisLevel);
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, uriNumber.toString(), ".json"))
                : "";
    }

    function myLog10(uint256 x) internal pure returns (uint256) {
        if (x == 0) {
            return 0;
        }
        uint256 result = 0;
        while (x >= 10) {
            x /= 10;
            result += 1;
        }
        return result;
    }

    receive() external payable {
        emit Received(_msgSender(), msg.value);
    }
    /***************Common interfaces END***************/

    /***************Author options BGN***************/
    function setManager(address newManager, uint256 author) public {
        require(ownerOf(author) == msg.sender, "You're not owner");
        managers[author] = newManager;
    }

    function addDonateAddress(address tokenAddress, uint256 author) supportsERC20(tokenAddress) onlyAuthor(author) public {
        address[] storage tokens = donateTokenAddressesByAuthor[author];
        require(!isAddressExist(tokenAddress, tokens), "Token already exists");
        tokens.push(tokenAddress);
    }

    function removeDonateAddress(address tokenAddress, uint256 author) supportsERC20(tokenAddress) onlyAuthor(author) public {
        address[] storage tokens = donateTokenAddressesByAuthor[author];
        require(isAddressExist(tokenAddress, tokens), "Token doesn't exist");
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenAddress) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }

    function isAddressExist(address _addressToCheck, address[] memory _collection) public pure returns (bool) {
        for (uint i = 0; i < _collection.length; i++) {
            if (_collection[i] == _addressToCheck) {
                return true;
            }
        }
        return false;
    }

    function createNewSessionByEth(
        uint256 author, 
        uint256 price, 
        uint256 expirationTime, 
        uint256 maxParticipants, 
        Types typeOf, 
        string memory name) onlyAuthor(author) public{
            createNewSessionByToken(author, address(0), price, expirationTime, maxParticipants, typeOf, name);
        }

    function createNewSessionByToken(
        uint256 author, 
        address tokenAddress, 
        uint256 price, 
        uint256 expirationTime, 
        uint256 maxParticipants, 
        Types typeOf, 
        string memory name) supportsERC20(tokenAddress) onlyAuthor(author) public{
        Participants memory participants = Participants(
            new address[](0),
            new address[](0),
            new address[](0)
        );
        Session memory session = Session ({
            tokenAddress: tokenAddress,
            price: price,
            expirationTime: expirationTime,
            maxParticipants: maxParticipants,
            name: name,
            typeOf: typeOf,
            participants: participants
        });
        sessionByAuthor[author].push(session);
        emit NewSessionCreated(author, name, tokenAddress, price, expirationTime, maxParticipants, typeOf);
    }

    function addToWhiteList(address user, uint256 author) onlyAuthor(author) public {
        whiteListByAuthor[author][user] = true;
    }

    function removeWhiteList(address user, uint256 author) onlyAuthor(author) public {
        whiteListByAuthor[author][user] = false;
    }

    function addToBlackList(address user, uint256 author) onlyAuthor(author) public {
        blackListByAuthor[author][user] = true;
    }

    function removeBlackList(address user, uint256 author) onlyAuthor(author) public {
        blackListByAuthor[author][user] = false;
    }

    function confirmParticipants(address participant, uint256 author, uint256 sessionId) onlyAuthor(author) public returns(bool) {
        Session storage session = sessionByAuthor[author][sessionId];
        Participants storage participants = session.participants;
        require(!isAddressExist(msg.sender, participants.rejected), "Participant is denied this session");
        address[] storage notConfirmed = participants.notConfirmed;
        for (uint i = 0; i < notConfirmed.length; i++) {
            if (notConfirmed[i] == participant) {
                notConfirmed[i] = notConfirmed[notConfirmed.length - 1];
                notConfirmed.pop();
                participants.confirmed.push(participant);
                unblockAndPay(author, session.tokenAddress, session.price);
                emit PurchaseConfirmed(participant, author, sessionId);
                return true;
            }
        }
        return false;
    }

    function unconfirmParticipants(address participant, uint256 author, uint256 sessionId) onlyAuthor(author) public returns(bool) {
        Session storage session = sessionByAuthor[author][sessionId];
        Participants storage participants = session.participants;
        require(!isAddressExist(msg.sender, participants.rejected), "Participant is denied this session");
        address[] storage notConfirmed = participants.notConfirmed;
        for (uint i = 0; i < notConfirmed.length; i++) {
            if (notConfirmed[i] == participant) {
                notConfirmed[i] = notConfirmed[notConfirmed.length - 1];
                notConfirmed.pop();
                participants.rejected.push(participant);
                unblockAndReject(participant, session.tokenAddress, session.price);
                emit PurchaseRejected(participant, author, sessionId);
                return true;
            }
        }
        return false;
    }

    function unblockAndPay(uint256 author, address tokenAddress, uint256 tokenAmount) internal nonReentrant {
        uint256 balanseFromEth = tokenAmount;
        if (tokenAddress == address(0)){
            paymentEth(author, tokenAmount);
        } else {
            IERC20 token = IERC20(tokenAddress);
            uint256 contractBalance = token.balanceOf(address(this));
            if (contractBalance < tokenAmount){
                tokenAmount = contractBalance;
            }
            uint256 contractFee = contractFeeForAuthor(author, tokenAmount);
            token.transfer(owner(), contractFee);
            uint256 amount = tokenAmount - contractFee;
            token.transfer(ownerOf(author), amount);
            
            balanseFromEth = getTokenPrice(tokenAddress);
            authorsAmounts[author] += balanseFromEth;
            totalAmounts += balanseFromEth;
        }
        authorsAmounts[author] += balanseFromEth;
        totalAmounts += balanseFromEth;
        blockedForWithdraw[tokenAddress] -= tokenAmount;
    }

    function unblockAndReject(address participant, address tokenAddress, uint256 tokenAmount) internal nonReentrant {
        if (tokenAddress == address(0)){
            (bool success, ) = participant.call{value: tokenAmount}("");
            require(success, "payment failed");
        } else {
            IERC20 token = IERC20(tokenAddress);
            uint256 contractBalance = token.balanceOf(address(this));
            if (contractBalance < tokenAmount){
                tokenAmount = contractBalance;
            }
            token.transfer(participant, tokenAmount);
        }
        blockedForWithdraw[tokenAddress] -= tokenAmount;
    }
    /***************Author options END***************/

    /***************User interfaces BGN***************/
    function contractFeeForAuthor(uint256 author, uint256 amount) public view returns(uint256){
        uint256 thisLevel = (10 ** levels) * authorsAmounts[author] / totalAmounts;
        return amount * 2 / ( 100 * (2 ** myLog10(thisLevel)));
    }

    function paymentEth(uint256 author, uint256 value) internal nonReentrant {
        uint256 contractFee = contractFeeForAuthor(author, value);
        (bool success, ) = owner().call{value: contractFee}("");
        require(success, "payment failed");
        uint256 amount = value - contractFee;
        (success, ) = ownerOf(author).call{value: amount}("");
        require(success, "payment failed");
        authorsAmounts[author] += value;
        totalAmounts += value;
    }

    function paymentToken(address tokenAddress, uint256 tokenAmount, uint256 author) internal nonReentrant {
        address[] memory tokens = donateTokenAddressesByAuthor[author];
        require(isAddressExist(tokenAddress, tokens), "Token doesn't exist");

        IERC20 token = IERC20(tokenAddress);
        uint256 userBalance = token.balanceOf(msg.sender);
        require(userBalance >= tokenAmount, "Balance is not enough");

        uint256 userAllowance = token.allowance(msg.sender, address(this));
        require(userAllowance >= tokenAmount, "Allowance is not enough");

        uint256 contractFee = contractFeeForAuthor(author, tokenAmount);
        token.transferFrom(msg.sender, owner(), contractFee);
        uint256 amount = tokenAmount - contractFee;
        token.transferFrom(msg.sender, ownerOf(author), amount);
        
        uint256 balanseFromEth = getTokenPrice(tokenAddress);
        authorsAmounts[author] += balanseFromEth;
        totalAmounts += balanseFromEth;
    }

    function blockTokens(address tokenAddress, uint256 tokenAmount) internal nonReentrant {
        if (tokenAddress != address(0)){
            IERC20 token = IERC20(tokenAddress);
            uint256 userBalance = token.balanceOf(msg.sender);
            require(userBalance >= tokenAmount, "Balance is not enough");
            uint256 userAllowance = token.allowance(msg.sender, address(this));
            require(userAllowance >= tokenAmount, "Allowance is not enough");
            token.transferFrom(msg.sender, address(this), tokenAmount);
        }
        blockedForWithdraw[tokenAddress] += tokenAmount;
    }

    function donateEth(uint256 author) public payable{
        require(msg.value > 0, "Donation is too low");
        paymentEth(author, msg.value);
        emit Donate(msg.sender, address(0), msg.value, author);
    }

    function donateToken(address tokenAddress, uint256 tokenAmount, uint256 author) public{
        require(tokenAmount > 0, "Donation is too low");
        paymentToken(tokenAddress, tokenAmount, author);
        emit Donate(msg.sender, tokenAddress, tokenAmount, author);
    }

    function buyTicketForSession(uint256 author, uint256 sessionId) public sessionIsOpenForSender(author, sessionId) payable{
        Session storage session = sessionByAuthor[author][sessionId];
        Participants storage participants = session.participants;
        address tokenAddress = session.tokenAddress;
        uint256 price = session.price;

        if (whiteListByAuthor[author][msg.sender] || session.typeOf == Types.notModerated){
            if (tokenAddress == address(0)){
                require(tokenAddress == address(0) && price == msg.value, "Error in payment value");
                paymentEth(author, msg.value);
            } else {
                paymentToken(tokenAddress, price, author);
            }
            participants.confirmed.push(msg.sender);
            emit PurchaseConfirmed(msg.sender, author, sessionId);
        } else {
            blockTokens(tokenAddress, price);
            participants.notConfirmed.push(msg.sender);
            emit PurchaseIsAwaitingConfirmation(msg.sender, author, sessionId);
        }
    }

    function cancelByParticipant(uint256 author, uint256 sessionId) public nonReentrant returns(bool) {
        Session storage session = sessionByAuthor[author][sessionId];
        Participants storage participants = session.participants;
        require(isAddressExist(msg.sender, participants.notConfirmed), "You are not in the lists of participants");
        require(!isAddressExist(msg.sender, participants.confirmed), "You have already signed up for the session, contact the author to cancel");
        address[] storage notConfirmed = participants.notConfirmed;
        for (uint i = 0; i < notConfirmed.length; i++) {
            if (notConfirmed[i] == msg.sender) {
                notConfirmed[i] = notConfirmed[notConfirmed.length - 1];
                notConfirmed.pop();
                unblockAndReject(msg.sender, session.tokenAddress, session.price);
                emit PurchaseCanceled(msg.sender, author, sessionId);
                return true;
            }
        }
        return false;
    }

    function getTokenPrice(address tokenAddress) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = uniswapRouter.WETH();
        uint256[] memory amountsOut = uniswapRouter.getAmountsOut(1 ether, path);
        return amountsOut[1];
    }
    /***************User interfaces END***************/

    /***************Royalty BGN***************/
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(tokenId), "query for nonexistent token");
        return (address(this), (salePrice * royaltyFee) / 10000);
    }    

    function setRoyaltyFee(uint16 fee) external onlyOwner {
        require (fee < 10000, "fee is too high");
        royaltyFee = fee;
    }

    function withdraw() external onlyOwner nonReentrant {
        require(address(this).balance > blockedForWithdraw[address(0)], "Eth balance not enough");
        uint256 amount = address(this).balance - blockedForWithdraw[address(0)];
        (bool success, ) = _msgSender().call{value: amount}("");
        require(success, "withdraw failed");
    }

    function withdrawTokens(address _address) external onlyOwner nonReentrant {
        IERC20 token = IERC20(_address);
        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance > blockedForWithdraw[_address], "Token balance not enough");
        uint256 amount = tokenBalance - blockedForWithdraw[_address];
        token.transfer(_msgSender(), amount);
    }
    /***************Royalty END**************/
}