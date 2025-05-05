// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IURUS } from "src/interfaces/IURUS.sol";
import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IIntentsNFT } from "src/interfaces/IIntentsNFT.sol";
import { IGRAI } from "src/interfaces/IGRAI.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";

interface IGrinderAI {

    error InvalidLength();
    error NotOwner();
    error NotDelegate();

    enum Op { 
        LONG_BUY, 
        LONG_SELL, 
        HEDGE_SELL, 
        HEDGE_REBUY, 
        BRANCH, 
        UNBRANCH
    }

    function DENOMINATOR() external view returns (uint16);

    function poolsNFT() external view returns (IPoolsNFT);

    function intentsNFT() external view returns (IIntentsNFT);

    function grAI() external view returns (IGRAI);

    function weth() external view returns (IWETH9);

    function grinder() external view returns (address payable);

    function grinderShareNumerator() external view returns (uint16);

    function liquidityShareNumerator() external view returns (uint16);

    function isDelegate(address account) external view returns (bool);

    function mintedGrinds(address account) external view returns (uint256);

    function init(address _poolsNFT, address _intentsNFT, address _grAI, address _weth) external;

    function owner() external view returns (address);

    function setDelegate(address _delegate, bool _isAgent) external;

    function setShares(uint16 _grinderShareNumerator, uint16 _liquidityShareNumerator) external;

    function setGrinder(address payable _grinder) external;

    function setLzReceivOptions(uint32 endpointId, uint128 gasLimit, uint128 value) external;

    function setMultiplierNumerator(uint256 _multiplierNumerator) external;

    function setNativeBridgeFee(uint256 _nativeBridgeFeeNumerator) external;

    function setPeer(uint32 eid, bytes32 peer) external;

    function grind(uint256 poolId) external returns (bool);

    function batchGrind(uint256[] memory poolIds) external;

    function grindOp(uint256 poolId, uint8 op) external returns (bool);

    function batchGrindOp(uint256[] memory poolIds, uint8[] memory ops) external;

    function setConfig(uint256 poolId, IURUS.Config memory config) external;

    function batchSetConfig(uint256[] memory poolIds, IURUS.Config[] memory configs) external;

    function setLongNumberMax(uint256 poolId, uint8 longNumberMax) external;

    function setHedgeNumberMax(uint256 poolId, uint8 hedgeNumberMax) external;

    function setExtraCoef(uint256 poolId, uint256 extraCoef) external;

    function setPriceVolatilityPercent(uint256 poolId, uint256 priceVolatilityPercent) external;

    function setOpReturnPercent(uint256 poolId, uint8 op, uint256 returnPercent) external;

    function setOpFeeCoef(uint256 poolId, uint8 op, uint256 _feeCoef) external;

    function executeGRAI(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

}