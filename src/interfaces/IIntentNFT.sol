// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IIntentNFT {

    error NotOwner();
    error NotPaymentToken();
    error BelowMinPeriod();

    event SetRatePerOneDay(address token, uint256 _ratePerOneDay);
    event Mint(uint256 intentId, address to, uint256 expire);
    event Extended(uint256 intentId, address to, uint256 newExpire);
    event Pay(address paymentToken, address payer, uint256 paymentAmount);

    struct Intent {
        address owner;
        uint256 expire;
        uint256[] poolIds;
    }

    function ONE_DAY() external view returns (uint256);

    function totalIntents() external view returns (uint256);

    function baseURI() external view returns (string memory);

    function expire(uint256 intentId) external view returns (uint256);

    function intentIdOf(address account) external view returns (uint256);

    function ratePerOneDay(address paymentToken) external view returns (uint256);

    function setRatePerOneDay(address token, uint256 _ratePerOneDay) external;

    function setBaseURI(string memory _baseURI) external;

    function mint(address paymentToken, uint256 period) external payable returns (uint256);

    function mintTo(address paymentToken, address to, uint256 period) external payable returns (uint256);

    function transfer(address to, uint256 intentId) external;

    function owner() external view returns (address);

    function calcPayment(address paymentToken, uint256 period) external view returns (uint256 paymentAmount); 

    function getIntentBy(uint256 poolId) external view returns ( 
        address _account,
        uint256 _expire, 
        uint256[] memory _poolIds
    );

    function getIntentOf(address account) external view returns ( 
        address _account,
        uint256 _expire, 
        uint256[] memory _poolIds
    );

    function getIntents(uint256[] memory intentIds) external view returns (Intent[] memory _intents);

    function tokenURI(uint256 poolId) external view returns (string memory uri);

    function totalSupply() external view returns (uint256);

    function isPaymentToken(address paymentToken) external view returns (bool);

    function chainId() external view returns (uint256 id);

    function execute(address target, uint256 value, bytes calldata data) external returns (bool success, bytes memory result);

}