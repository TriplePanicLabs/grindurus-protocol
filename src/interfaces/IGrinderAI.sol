// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IURUS } from "src/interfaces/IURUS.sol";
import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IIntentsNFT } from "src/interfaces/IIntentsNFT.sol";
import { IGRAI } from "src/interfaces/IGRAI.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";

interface IGrinderAI {

    error FailTransferETH();
    error InvalidLength();
    error InvalidShares();
    error NotPaymentToken();
    error NotOwner();
    error NotMicroOp();
    error NotMacroOp();

    event Pay(address paymentToken, address payer, uint256 paymentAmount);

    enum Op {
        // micro operations
        LONG_BUY,   // 0
        LONG_SELL,  // 1
        HEDGE_SELL, // 2
        HEDGE_REBUY,// 3 
        // macro operations
        BRANCH,     // 4
        UNBRANCH    // 5
    }

    function DENOMINATOR() external view returns (uint16);

    function poolsNFT() external view returns (IPoolsNFT);

    function grAI() external view returns (IGRAI);

    function weth() external view returns (IWETH9);

    function grinder() external view returns (address payable);

    function grinderShareNumerator() external view returns (uint16);

    function liquidityShareNumerator() external view returns (uint16);

    function init(address _poolsNFT, address _grAI, address _weth) external;

    function owner() external view returns (address);

    function setRatePerGRAI(address paymentToken, uint256 rate) external;

    function setBurnRate(uint256 _graiBurnRate) external;

    function setShares(uint16 _grinderShareNumerator, uint16 _liquidityShareNumerator) external;

    function setGrinder(address payable _grinder) external;

    function setLzReceivOptions(uint32 endpointId, uint128 gasLimit, uint128 value) external;

    function setMultiplierNumerator(uint256 _multiplierNumerator) external;

    function setArtificialFeeNumerator(uint32 endpointId, uint256 artificialFeeNumerator) external;

    function setPeer(uint32 eid, bytes32 peer) external;

    function withdraw(address token, uint256 amount) external returns (uint256);

    function withdrawTo(address token, address to, uint256 amount) external returns (uint256 withdrawn);

    function calcPayment(address paymentToken, uint256 graiAmount) external view returns (uint256 paymentAmount);

    function mint(address paymentToken, uint256 graiAmount) external payable returns (uint256);

    function mintTo(address paymentToken, address to, uint256 graiAmount) external payable returns (uint256);

    function grind(uint256 poolId) external returns (bool);

    function batchGrind(uint256[] memory poolIds) external;

    function microOp(uint256 poolId, uint8 op) external returns (bool success);

    function macroOp(uint256 poolId, uint8 op) external returns (bool);

    function grindOp(uint256 poolId, uint8 op) external returns (bool);

    function batchGrindOp(uint256[] memory poolIds, uint8[] memory ops) external;

    function getIntentOf(address account) external view returns (
        address _account,
        uint256 _grinds,
        uint256[] memory _poolIds
    );

    function isPaymentToken(address paymentToken) external view returns (bool);

    function executeGRAI(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

}