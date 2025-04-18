// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IIntentsNFT, IPoolsNFT, IGRAI} from "src/interfaces/IIntentsNFT.sol";
import {Base64} from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

/// @title IntentsNFT
/// @notice SoulBoundToken
/// @dev store intents for grind onchain. Used by GrinderAI
contract IntentsNFT is IIntentsNFT, ERC721 {
    using SafeERC20 for IToken;
    using Base64 for bytes;
    using Strings for uint256;

    /// @notice base URI for this collection
    string public baseURI;

    /// @dev address of pools NFT, where grab poolIds for intent
    IPoolsNFT public poolsNFT;

    /// @dev address of grAI token
    IGRAI public grAI;

    /// @dev address of receiver of funds
    address payable public grinder;

    /// @dev total supply
    uint256 public totalIntents;

    /// @notice free grinds for user
    uint256 public freemiumGrinds;

    /// @notice total amount of grinds
    uint256 public totalGrinds;

    /// @dev address of owner of intent => intent id
    mapping (address account => uint256) public intentIdOf;

    /// @dev address of account => total grinds earned
    mapping (address account => uint256) public grindsOf;

    /// @dev id of intent => grinds amount
    mapping (uint256 intentId => uint256) public grinds;

    /// @dev address of token => rate of token per one day
    /// @dev token is address(0), this is ETH. Else ERC20 token
    /// @dev if ratePerGrind==type(uint256).max, than payment if free on `paymentToken`
    /// @dev if ratePerGrind==0, than this is not payment token
    mapping (address paymentToken => uint256) public ratePerGrind;

    /// @param _poolsNFT address of poolsNFT
    constructor(address _poolsNFT, address _grAI) ERC721("GrinderAI Intents Collection", "grAI_INTENTS") {
        poolsNFT = IPoolsNFT(_poolsNFT);
        grAI = IGRAI(_grAI);
        grinder = owner();
        ratePerGrind[address(0)] = 0.0001 ether; // may be changed by owner
        freemiumGrinds = 5;
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice sets freemium grinds
    /// @param _freemiumGrinds amount of free grinds
    function setFreemiumGrinds(uint256 _freemiumGrinds) public {
        _onlyOwner();
        freemiumGrinds = _freemiumGrinds;
    }

    /// @notice sets funds receiver
    /// @param _grinder address of funds receiver
    function setGrinder(address payable _grinder) public {
        _onlyOwner();
        grinder = _grinder;
    }

    /// @param token address of token
    /// @param _ratePerGrind rate of token one grind
    function setRatePerGrind(address token, uint256 _ratePerGrind) public override {
        _onlyOwner();
        ratePerGrind[token] = _ratePerGrind;
        emit SetRatePerGrind(token, _ratePerGrind);
    }

    /// @notice sets base URI
    /// @param _baseURI string with baseURI
    function setBaseURI(string memory _baseURI) external override {
        _onlyOwner();
        baseURI = _baseURI;
    }

    /// @notice mints intent on behalf of `msg.sender`
    /// @param _grinds amount of grinds
    function mint(address paymentToken, uint256 _grinds) public payable override returns (uint256, uint256) {
        return mintTo(paymentToken, msg.sender, _grinds);
    }

    /// @notice mints intent on behalf of `to`
    /// @param paymentToken address of payment token
    /// @param to address of `to`
    /// @param _grinds amount of grinds
    function mintTo(address paymentToken, address to, uint256 _grinds) public payable override returns (uint256 intentId, uint256 grindsAcquired) {
        uint256 paymentAmount = calcPayment(paymentToken, _grinds);
        _pay(paymentToken, grinder, paymentAmount);
        (intentId, grindsAcquired) = _mintTo(to, _grinds);
        _airdrop(to, grindsAcquired);
    }

    /// @notice pays for the mint
    /// @param paymentToken address of payment token
    /// @param receiver address of receiver
    function _pay(address paymentToken, address payable receiver, uint256 paymentAmount) internal returns (uint256 paid) {
        if (paymentAmount > 0) {
            if (paymentToken == address(0)) {
                (bool success, ) = receiver.call{value: paymentAmount}("");
                require(success, "fail send ETH");
            } else {
                IToken(paymentToken).safeTransferFrom(msg.sender, receiver, paymentAmount);
            }
            emit Pay(paymentToken, msg.sender, paymentAmount);
        }
        paid = paymentAmount;
    }

    /// @notice mints intent to `to` with defined period
    function _mintTo(address to, uint256 _grinds) internal returns (uint256 intentId, uint256 grindsAcquired) {
        grindsAcquired = 0;
        if (balanceOf(to) == 0) {
            intentId = totalIntents;
            _mint(to, intentId);
            intentIdOf[to] = intentId;
            if (grindsOf[to] == 0) {
                grinds[intentId] += freemiumGrinds;
                grindsAcquired += freemiumGrinds;
            }
            totalIntents++;
        } else {
            intentId = intentIdOf[to];
        }
        grindsAcquired += _grinds;
        grindsOf[to] += grindsAcquired;
        grinds[intentId] += grindsAcquired;
        totalGrinds += grindsAcquired;
        emit Mint(intentId, to, grindsAcquired);
    }

    /// @notice airdrops GRAI to `to`
    /// @param to address of receiver
    /// @param grindsAquired amount of grinds aquired
    function _airdrop(address to, uint256 grindsAquired) internal {
        uint256 graiAmount = grindsAquired * 1e18;
        grAI.mint(to, graiAmount);
    }

    /// @notice not transferable. Use mint(). Use mint()
    function transferFrom(address, address, uint256) public override {
        baseURI = baseURI;
        revert NotTransferable();
    }

    /// @notice return owner of intent NFT collection
    function owner() public view returns (address payable) {
        try poolsNFT.owner() returns (address payable _owner) {
            return _owner;
        } catch {
            return payable(address(poolsNFT));
        }
    }

    /// @notice calculate payment
    /// @param paymentToken address of token
    /// @param _grinds amount of time in seconds
    function calcPayment(address paymentToken, uint256 _grinds) public view override returns (uint256 paymentAmount) {      
        if (!isPaymentToken(paymentToken)) {
            revert NotPaymentToken();
        }
        if (ratePerGrind[paymentToken] == type(uint256).max) { // free
            paymentAmount = 0;
        } else {
            paymentAmount = ratePerGrind[paymentToken] * _grinds;
        }
    }

    /// @notice return spent grinds
    function spentGrinds(uint256 intentId) public view returns (uint256) {
        return poolsNFT.spentGrinds(ownerOf(intentId));
    }

    /// @notice onchain function to get unspent grinds
    function unspentGrinds(uint256 intentId) public view returns (uint256) {
        uint256 _spentGrinds = spentGrinds(intentId);
        if (_spentGrinds <= grinds[intentId]){
            return grinds[intentId] - _spentGrinds;
        } else {
            return 0;
        }
    }

    /// @notice get intent by `poolId` on `poolsNFT`
    /// @param poolId id of pool on poolsNFT
    function getIntentBy(uint256 poolId) public view override 
        returns (
            address _account,
            uint256 _grinds, 
            uint256[] memory _poolIds
        )
    {
        _account = poolsNFT.ownerOf(poolId);
        _grinds = grinds[intentIdOf[_account]];
        _poolIds = poolsNFT.getPoolIdsOf(_account);
    }

    /// @notice get intent of `_account`
    /// @param _account address of account
    function getIntentOf(address account) public view override returns (
        address _account,
        uint256 _grinds, 
        uint256[] memory _poolIds
    ) {
        uint256 intentId = intentIdOf[account];
        _account = ownerOf(intentId);
        _grinds = grinds[intentId];
        _poolIds = poolsNFT.getPoolIdsOf(_account);
    }

    /// @notice get intent by intentId
    /// @param intentId id of intent
    function getIntent(uint256 intentId) public view returns (Intent memory intent) {
        intent = Intent({
            owner: ownerOf(intentId),
            grinds: grinds[intentId],
            poolIds: poolsNFT.getPoolIdsOf(ownerOf(intentId))
        });
    }

    /// @notice get intents array
    /// @param intentIds array of intents ids
    function getIntents(uint256[] memory intentIds) public view override returns (Intent[] memory intents) {
        uint256 len = intentIds.length;
        intents = new Intent[](len);
        for (uint256 i; i < len;) {
            intents[i] = getIntent(intentIds[i]);
            unchecked { ++i; }
        }
    }

    /// @notice returns tokenURI of `tokenId`
    /// @param intentId pool id of pool in array `pools`
    /// @return uri unified reference indentificator for `tokenId`
    function tokenURI(
        uint256 intentId
    )
        public
        view
        override(ERC721, IIntentsNFT)
        returns (string memory uri)
    {
        _requireOwned(intentId);
        uri = baseURI;
    }

    /// @notice return total supply of NFTs
    function totalSupply() public view override returns (uint256) {
        return totalIntents;
    }

    /// @notice return true if `paymentToken` is payment token 
    function isPaymentToken(address paymentToken) public view override returns (bool) {
        return ratePerGrind[paymentToken] > 0;
    }

    /// @notice return chain id
    function chainId() public view override returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    /// @notice execute any transaction
    /// @param target addres of target smart contract
    /// @param value amount of ETH
    /// @param data calldata for transaction 
    function execute(address target, uint256 value, bytes calldata data) public payable virtual override returns (bool success, bytes memory result) {
        _onlyOwner();
        require(target != address(grAI), "grAI is not allowed");
        (success, result) = target.call{value: value}(data);
    }

    receive() external payable {
        if (msg.value > 0) {
            (bool success, ) = address(grinder).call{value: msg.value}("");
            success;
        }
    }

}