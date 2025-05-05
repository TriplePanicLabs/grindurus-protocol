// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IGRAI } from "src/interfaces/IGRAI.sol";

interface IIntentsNFT {

    error InvalidBurnRate();
    error NotTransferable();
    error NotOwner();
    error NotGrinderAI();
    error NotPaymentToken();
    error Owned();

    event SetRatePerGrind(address token, uint256 _ratePerGrind);
    event Mint(uint256 intentId, address to, uint256 grinds);
    event Pay(address paymentToken, address payer, uint256 paymentAmount);

    struct Intent {
        address owner;
        uint256 grinds;
        uint256 spentGrinds;
        uint256 unspentGrinds;
        uint256[] poolIds;
    }

    function poolsNFT() external view returns (IPoolsNFT);

    function grAI() external view returns (IGRAI);

    function distributor() external view returns (address payable);

    function baseURI() external view returns (string memory);

    function totalIntents() external view returns (uint256);

    function freemiumGrinds() external view returns (uint256);

    function totalGrinds() external view returns (uint256);

    function intentIdOf(address account) external view returns (uint256);

    function grindsOf(address account) external view returns (uint256);

    function grinds(uint256 intentId) external view returns (uint256);

    function ratePerGrind(address paymentToken) external view returns (uint256);

    function setBurnRate(uint256 _burnRate) external;

    function setFreemiumGrinds(uint256 _freemiumGrinds) external;

    function setDistributor(address payable _distributor) external;

    function setRatePerGrind(address token, uint256 _ratePerGrind) external;

    function spentGrinds(uint256 intentId) external view returns (uint256);

    function unspentGrinds(uint256 intentId) external view returns (uint256);

    function setBaseURI(string memory _baseURI) external;

    function mint(address paymentToken, uint256 period) external payable returns (uint256, uint256);

    function mintTo(address paymentToken, address to, uint256 period) external payable returns (uint256, uint256);

    function owner() external view returns (address payable);

    function calcPayment(address paymentToken, uint256 grinds) external view returns (uint256 paymentAmount); 

    function getIntentBy(uint256 poolId) external view returns ( 
        address _account,
        uint256 _grinds,
        uint256 _spentGrinds,
        uint256 _unspentGrinds,
        uint256[] memory _poolIds
    );

    function getIntentOf(address account) external view returns ( 
        address _account,
        uint256 _grinds,
        uint256 _spentGrinds,
        uint256 _unspentGrinds,
        uint256[] memory _poolIds
    );

    function getIntents(uint256[] memory intentIds) external view returns (Intent[] memory _intents);

    function tokenURI(uint256 poolId) external view returns (string memory uri);

    function totalSupply() external view returns (uint256);

    function isPaymentToken(address paymentToken) external view returns (bool);

    function chainId() external view returns (uint256 id);

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

}