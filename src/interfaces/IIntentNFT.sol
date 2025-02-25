// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IIntentNFT {

    error NotOwner();
    error NotPaymentToken();
    error BelowMinPeriod();

    event SetRatePerOneDay(address token, uint256 _ratePerOneDay);

    function ONE_DAY() external view returns (uint256);

    function totalIntents() external view returns (uint256);

    function baseURI() external view returns (string memory);

    function expire(uint256 intentId) external view returns (uint256);

    function intentIdOf(address account) external view returns (uint256);

    function ratePerOneDay(address paymentToken) external view returns (uint256);

    function setIntentsNFTImage(address _intentsNFTImage) external;

    function setRatePerOneDay(address token, uint256 _ratePerOneDay) external;

    function setBaseURI(string memory _baseURI) external;

    function mint(address paymentToken, uint256 period) external payable returns (uint256);

    function mintTo(address paymentToken, address to, uint256 period) external payable returns (uint256);

    function transfer(address to, uint256 intentId) external;

    function owner() external view returns (address);

    function calcPayment(address paymentToken, uint256 period) external view returns (uint256 paymentAmount); 

    function getIntent(address account) external view returns ( 
        address _account,
        uint256 _expire, 
        uint256[] memory _poolIds
    );

    function tokenURI(uint256 poolId) external view returns (string memory uri);

    function totalSupply() external view returns (uint256);

    function isPaymentToken(address paymentToken) external view returns (bool);

    function chainId() external view returns (uint256 id);

}