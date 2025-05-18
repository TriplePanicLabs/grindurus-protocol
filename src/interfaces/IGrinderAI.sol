// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IURUS } from "src/interfaces/IURUS.sol";
import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IGRAI } from "src/interfaces/IGRAI.sol";

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
        // micro operations (URUS algorithm)
        LONG_BUY,   // 0
        LONG_SELL,  // 1
        HEDGE_SELL, // 2
        HEDGE_REBUY,// 3 
        // macro operations (Agent)
        BRANCH,     // 4
        UNBRANCH,   // 5
        ASYNC_WITHDRAW // 6
    }

    struct Intent {
        address account;
        uint256 grinds;
        uint256[] poolIds;
    }

    function DENOMINATOR() external view returns (uint16);

    function poolsNFT() external view returns (IPoolsNFT);

    function grAI() external view returns (IGRAI);

    function grinder() external view returns (address payable);

    function init(address _poolsNFT, address _grAI) external;

    function owner() external view returns (address payable);

    function setRatePerGRAI(address paymentToken, uint256 rate) external;

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

    function grindTo(uint256 poolId, address payable metaGrinder) external returns (bool);

    function batchGrind(uint256[] memory poolIds) external;

    function microOp(uint256 poolId, uint8 op) external returns (bool success);

    function microOpTo(uint256 poolId, uint8 op, address payable metaGrinder) external returns (bool success);

    function macroOp(uint256 poolId, uint8 op) external returns (bool success);

    function macroOpTo(uint256 poolId, uint8 op, address payable metaGrinder) external returns (bool success);

    function grindOp(uint256 poolId, uint8 op) external returns (bool);

    function grindOpTo(uint256 poolId, uint8 op, address payable metaGrinder) external returns (bool);

    function batchGrindOp(uint256[] memory poolIds, uint8[] memory ops) external;

    function getIntent(address account) external view returns (Intent memory intent);

    function getIntents(address[] memory accounts) external view returns (Intent[] memory intents);

    function getPnL(uint256 poolId) external view returns (IURUS.Profits memory) ;

    function getPnLBy(uint256[] memory poolIds) external view returns (IURUS.Profits[] memory profits);

    function isPaymentToken(address paymentToken) external view returns (bool);

    function executeGRAI(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

}