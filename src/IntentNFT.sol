// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {IIntentNFT} from "src/interfaces/IIntentNFT.sol";
import {IIntentsNFTImage} from "src/interfaces/IIntentsNFTImage.sol";
import {Base64} from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721, ERC721Enumerable} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "lib/forge-std/src/console.sol";

/// @title IntentNFT
/// @notice pseudoSoulBoundToken
/// @dev store intents for grind onchain. Used by GrinderAI
contract IntentNFT is IIntentNFT, ERC721 {
    using SafeERC20 for IToken;
    using Base64 for bytes;
    using Strings for uint256;

    /// @dev one day in seconds. Value 86400 seconds
    uint256 public constant ONE_DAY = 1 days;

    /// @dev address of pools NFT, where grab poolIds for intent
    IPoolsNFT public poolsNFT;

    /// @dev address of intents NFT image 
    IIntentsNFTImage public intentsNFTImage;

    /// @dev total supply
    uint256 public totalIntents;

    /// @notice base URI for this collection
    string public baseURI;

    /// @dev id of intent => expire date
    mapping (uint256 intentId => uint256) public expire;

    /// @dev address of owner of intent => intent id
    mapping (address account => uint256) public intentIdOf;

    /// @dev address of token => rate of token per one day
    /// @dev token is address(0), this is ETH. Else ERC20 token
    mapping (address paymentToken => uint256) public ratePerOneDay;

    /// @param _poolsNFT address of poolsNFT
    constructor(address _poolsNFT) ERC721("GrinderAI Intents Collection", "grAI_INTENTS") {
        poolsNFT = IPoolsNFT(_poolsNFT);
        ratePerOneDay[address(0)] = 0.0001 ether; // may be changed by owner
        uint256 zeroIntentId = 0;
        address deployer = msg.sender;
        _mint(deployer, zeroIntentId);
        expire[zeroIntentId] = block.timestamp + 999999999999;
        totalIntents = 1;
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice set the intent nft image
    /// @param _intentsNFTImage address of intents nft image
    function setIntentsNFTImage(address _intentsNFTImage) public override {
        _onlyOwner();
        intentsNFTImage = IIntentsNFTImage(_intentsNFTImage);
    }

    /// @param token address of token
    /// @param _ratePerOneDay rate of token per one day
    function setRatePerOneDay(address token, uint256 _ratePerOneDay) public override {
        _onlyOwner();
        ratePerOneDay[token] = _ratePerOneDay;
    }

    /// @notice sets base URI
    /// @param _baseURI string with baseURI
    function setBaseURI(string memory _baseURI) external override {
        _onlyOwner();
        baseURI = _baseURI;
    }

    /// @notice mints intent on behalf of `msg.sender`
    /// @param period amount of time in seconds
    function mint(address paymentToken, uint256 period) public payable override returns (uint256) {
        return mintTo(paymentToken, msg.sender, period);
    }

    /// @notice mints intent on behalf of `to`
    /// @param paymentToken address of payment token
    /// @param to address of `to`
    /// @param period amount of time in seconds
    function mintTo(address paymentToken, address to, uint256 period) public payable override returns (uint256 intentId) {
        uint256 paymentAmount = calcPayment(paymentToken, period);
        _pay(paymentToken, owner(), paymentAmount);
        intentId = _mintTo(to, period);
    }

    /// @notice mints intent to `to` with defined period
    function _mintTo(address to, uint256 period) public returns (uint256 intentId) {
        if (balanceOf(to) == 0) {
            intentId = totalIntents;
            expire[intentId] = block.timestamp + period;
            intentIdOf[to] = intentId;
            _mint(to, intentId);
            totalIntents++;
        } else {
            intentId = intentIdOf[to];
            uint256 blockTimestamp = block.timestamp;
            if (blockTimestamp > expire[intentId]) {
                expire[intentId] = blockTimestamp + period;
            } else {
                expire[intentId] += period;
            }
        }
    }

    /// @notice transfer intent from msg.sender to `to`
    /// @param to address of receiver of intent id
    /// @param intentId id of intent
    function transfer(address to, uint256 intentId) public override {
        _transfer(msg.sender, to, intentId);
    }

    /// @notice updates the ownership of NFT
    /// @param to address or receiver of NFT
    /// @param tokenId id of intent id
    /// @param auth authenticated sender
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);
        if (to == address(0)) {
            return previousOwner;
        }
        intentIdOf[previousOwner] = 0;
        intentIdOf[to] = tokenId;
        return previousOwner;
    }

    /// @notice pays for the mint
    /// @param paymentToken address of payment token
    /// @param receiver address of receiver
    function _pay(address paymentToken, address receiver, uint256 paymentAmount) internal returns (uint256 paid) {
        if (paymentAmount == type(uint256).max) { // free
            return 0;
        }
        if (paymentToken == address(0)) {
            (bool success, ) = receiver.call{value: paymentAmount}("");
            require(success, "fail send ETH");
        } else {
            IToken(paymentToken).safeTransferFrom(msg.sender, receiver, paymentAmount);
        }
        paid = paymentAmount;
    }

    /// @notice return owner of intent NFT collection
    function owner() public view returns (address) {
        try poolsNFT.owner() returns (address payable _owner) {
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice calculate payment
    /// @param paymentToken address of token
    /// @param period amount of time in seconds
    function calcPayment(address paymentToken, uint256 period) public view override returns (uint256 paymentAmount) {      
        paymentAmount = ratePerOneDay[paymentToken] * period / ONE_DAY;
    }

    /// @notice get intent of `_account`
    /// @param _account address of account
    function getIntent(address account) public view override returns (
        address _account,
        uint256 _expire, 
        uint256[] memory _poolIds
    ) {
        uint256 poolIdsLen;
        uint256 intentId = intentIdOf[account];
        _account = ownerOf(intentId);
        _expire = expire[intentId];
        (poolIdsLen, _poolIds) = poolsNFT.getPoolIdsOf(_account);
    }

    /// @notice returns tokenURI of `tokenId`
    /// @param poolId pool id of pool in array `pools`
    /// @return uri unified reference indentificator for `tokenId`
    function tokenURI(
        uint256 poolId
    )
        public
        view
        override(ERC721, IIntentNFT)
        returns (string memory uri)
    {
        _requireOwned(poolId);
        if (address(intentsNFTImage) == address(0)) {
            // https://raw.githubusercontent.com/TriplePanicLabs/GrindURUS-PoolsNFTsData/refs/heads/main/arbitrum/{poolId}.json
            string memory path = string.concat(baseURI, poolId.toString());
            uri = string.concat(path, ".json");
        } else {
            uri = intentsNFTImage.URI(poolId);
        }
    }

    /// @notice return total supply of NFTs
    function totalSupply() public view override returns (uint256) {
        return totalIntents;
    }

}