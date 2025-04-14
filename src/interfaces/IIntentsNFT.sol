// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IIntentsNFT {

    error NotOwner();
    error NotPaymentToken();
    error Owned();

    event SetRatePerGrind(address token, uint256 _ratePerGrind);
    event Mint(uint256 intentId, address to, uint256 grinds);
    event Pay(address paymentToken, address payer, uint256 paymentAmount);

    struct Intent {
        address owner;
        uint256 grinds;
        uint256[] poolIds;
    }

    function totalIntents() external view returns (uint256);

    function baseURI() external view returns (string memory);

    function grinds(uint256 intentId) external view returns (uint256);

    function intentIdOf(address account) external view returns (uint256);

    function ratePerGrind(address paymentToken) external view returns (uint256);

    function setRatePerGrind(address token, uint256 _ratePerGrind) external;

    function setBaseURI(string memory _baseURI) external;

    function mint(address paymentToken, uint256 period) external payable returns (uint256);

    function mintTo(address paymentToken, address to, uint256 period) external payable returns (uint256);

    function transfer(address to, uint256 intentId) external;

    function owner() external view returns (address payable);

    function calcPayment(address paymentToken, uint256 grinds) external view returns (uint256 paymentAmount); 

    function getIntentBy(uint256 poolId) external view returns ( 
        address _account,
        uint256 _grinds, 
        uint256[] memory _poolIds
    );

    function getIntentOf(address account) external view returns ( 
        address _account,
        uint256 _grinds, 
        uint256[] memory _poolIds
    );

    function getIntents(uint256[] memory intentIds) external view returns (Intent[] memory _intents);

    function tokenURI(uint256 poolId) external view returns (string memory uri);

    function totalSupply() external view returns (uint256);

    function isPaymentToken(address paymentToken) external view returns (bool);

    function chainId() external view returns (uint256 id);

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

}