// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IOFT, SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

interface IGRAI is IOFT {

    struct LzReceiveOptions {
        uint128 gasLimit;
        uint128 value;
    }

    error NotGrinderAI();
    error InsufficientNativeFee();

    event Bridge(
        address initiator,
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount,
        uint256 nativeFee,
        uint256 nativeBridgeFee
    );

    function multiplierNumerator() external view returns (uint256);

    function nativeBridgeFeeNumerator() external view returns (uint256);

    function setLzReceivOptions(uint32 endpointId, uint128 gasLimit, uint128 value) external;

    function setMultiplierNumerator(uint256 _multiplierNumerator) external;

    function setNativeBridgeFee(uint256 _nativeBridgeFeeNumerator) external;

    function setPeer(uint32 _eid, bytes32 _peer) external;

    function mint(address to, uint256 amount) external; 

    function bridgeTo(
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount
    ) external payable;

    function formSendParamsForBridgeTo(
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount
    ) external view returns (SendParam memory sendParam);

    function formMessagingFeeForBridgeTo(SendParam memory sendParam) external view returns (MessagingFee memory messagingFee);

    function getTotalFeesForBridgeTo(
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount
    ) external view returns (
        uint256 nativeFee, 
        uint256 nativeBridgeFee, 
        uint256 totalNativeFee
    );

    function estimateBridgeFee(
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount
    ) external view returns (uint256 nativeFee);

    function calcBridgeFee(
        uint256 nativeFee
    ) external view returns (uint256);

    function addressToBytes32(address addr) external pure returns (bytes32);

    function bytes32ToAddress(bytes32 b) external pure returns (address);

    function execute(address target, uint256 value, bytes memory data) external payable returns (bool success, bytes memory result);

}