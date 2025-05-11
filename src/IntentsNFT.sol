// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IToken } from "src/interfaces/IToken.sol";
import { IIntentsNFT, IPoolsNFT, IGRAI } from "src/interfaces/IIntentsNFT.sol";
import { Base64 } from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

/// @title IntentsNFT
/// @notice SoulBoundToken
/// @dev store intents for grind onchain. Used by GrinderAI
contract IntentsNFT is IIntentsNFT, ERC721 {
    using SafeERC20 for IToken;
    using Base64 for bytes;
    using Strings for uint256;

    /// @dev 100% = 100_00
    uint256 public constant DENOMINATOR = 100_00;

    /// @notice base URI for this collection
    string public baseURI;

    /// @dev address of pools NFT, where grab poolIds for intent
    IPoolsNFT public poolsNFT;

    /// @dev address of grAI token
    IGRAI public grAI;

    /// @dev burn rate for grAI token
    uint256 public burnRate;

    /// @notice free grinds for user
    uint256 public freemiumGrinds;

    /// @dev total supply
    uint256 public totalIntents;

    /// @notice total amount of grinds
    uint256 public totalGrinds;

    /// @dev address of owner of intent => intent id
    mapping (address _ownerOf => uint256) public intentIdOf;

    /// @dev address of account => total grinds earned
    mapping (address _ownerOf => uint256) public grindsOf;

    /// @dev id of intent => grinds amount
    mapping (address _ownerOf => uint256) public grinds;

    /// @dev address of account => spent grinds amount
    mapping (address _ownerOf => uint256) public spentGrinds;

    /// @dev address of token => rate of token per one day
    /// @dev token is address(0), this is ETH. Else ERC20 token
    /// @dev if ratePerGrind==type(uint256).max, than payment if free on `paymentToken`
    /// @dev if ratePerGrind==0, than this is not payment token
    mapping (address paymentToken => uint256) public ratePerGrind;

    /// @param _poolsNFT address of poolsNFT
    constructor(address _poolsNFT, address _grAI) ERC721("GrinderAI Intents Collection", "grAI_INTENTS") {
        poolsNFT = IPoolsNFT(_poolsNFT);
        grAI = IGRAI(_grAI);
        ratePerGrind[address(0)] = 0.0001 ether; // 0.0001 ETH per grind
        ratePerGrind[_grAI] = 1 * 1e18; // 1 grAI per grind
        burnRate = 80_00; // 80%
        freemiumGrinds = 5;
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice sets burn rate
    /// @param _burnRate burn rate
    function setBurnRate(uint256 _burnRate) public override {
        _onlyOwner();
        if (_burnRate > DENOMINATOR) {
            revert InvalidBurnRate();
        }
        burnRate = _burnRate;
    }

    /// @notice sets freemium grinds
    /// @param _freemiumGrinds amount of free grinds
    function setFreemiumGrinds(uint256 _freemiumGrinds) public override {
        _onlyOwner();
        freemiumGrinds = _freemiumGrinds;
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
        _pay(paymentToken, grinderAI(), paymentAmount);
        (intentId, grindsAcquired) = _mintTo(to, _grinds);
        if (paymentToken != address(grAI)) {
            _airdrop(to, grindsAcquired);
        }
    }

    /// @notice pays for the mint
    /// @param paymentToken address of payment token
    /// @param receiver address of receiver
    function _pay(address paymentToken, address payable receiver, uint256 paymentAmount) internal returns (uint256 paid) {
        if (paymentAmount > 0) {
            if (paymentToken == address(0)) {
                (bool success, ) = receiver.call{value: paymentAmount}("");
                require(success, "fail send ETH");
            } else if (paymentToken == address(grAI)) {
                grAI.transferFrom(msg.sender, address(this), paymentAmount);
                uint256 burnAmount = (paymentAmount * burnRate) / DENOMINATOR;
                if (burnAmount > 0){
                    grAI.burn(receiver, burnAmount);
                }
                if (paymentAmount > burnAmount) {
                    uint256 amount = paymentAmount - burnAmount;
                    grAI.transfer(receiver, amount);
                }
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
                grinds[to] += freemiumGrinds;
                grindsAcquired += freemiumGrinds;
            }
            totalIntents++;
        } else {
            intentId = intentIdOf[to];
        }
        grinds[to] += _grinds;
        grindsAcquired += _grinds;
        grindsOf[to] += grindsAcquired;
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

    /// @notice increase spent grinds on behalf of owner of poolId
    /// @param poolId id of pool on poolsNFT
    function spendGrind(uint256 poolId) public override {
        if (msg.sender == grinderAI()) {
            address _ownerOf = poolsNFT.ownerOf(poolId);
            spentGrinds[_ownerOf] += 1;
        }
    }

    /// @notice not transferable
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

    /// @notice return address of grinderAI
    function grinderAI() public view override returns (address payable) {
        return payable(address(poolsNFT.grinderAI()));
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

    /// @notice onchain function to get unspent grinds
    /// @param _ownerOf address of owner of intent
    function unspentGrinds(address _ownerOf) public view returns (uint256) {
        uint256 _spentGrinds = spentGrinds[_ownerOf];
        if (_spentGrinds <= grinds[_ownerOf]){
            return grinds[_ownerOf] - _spentGrinds;
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
            uint256 _spentGrinds,
            uint256 _unspentGrinds,
            uint256[] memory _poolIds
        )
    {
        _account = poolsNFT.ownerOf(poolId);
        _grinds = grinds[_account];
        _spentGrinds = spentGrinds[_account];
        _unspentGrinds = unspentGrinds(_account);
        _poolIds = poolsNFT.getPoolIdsOf(_account);
    }

    /// @notice get intent of `_account`
    /// @param _account address of account
    function getIntentOf(address account) public view override returns (
        address _account,
        uint256 _grinds,
        uint256 _spentGrinds,
        uint256 _unspentGrinds,
        uint256[] memory _poolIds
    ) {
        _account = account;
        _grinds = grinds[account];
        _spentGrinds = spentGrinds[account];
        _unspentGrinds = unspentGrinds(account);
        _poolIds = poolsNFT.getPoolIdsOf(account);
    }

    /// @notice get intent by intentId
    /// @param intentId id of intent
    function getIntent(uint256 intentId) public view returns (Intent memory intent) {
        address _ownerOf = ownerOf(intentId);
        intent = Intent({
            owner: _ownerOf,
            grinds: grinds[_ownerOf],
            spentGrinds: spentGrinds[_ownerOf],
            unspentGrinds: unspentGrinds(_ownerOf),
            poolIds: poolsNFT.getPoolIdsOf(_ownerOf)
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
    /// @param intentId id of intent
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
            (bool success, ) = grinderAI().call{value: msg.value}("");
            success;
        }
    }

}