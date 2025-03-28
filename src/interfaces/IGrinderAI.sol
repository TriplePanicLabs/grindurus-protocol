// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IURUS} from "src/interfaces/IURUS.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";

interface IGrinderAI {

    error InvalidLength();
    error NotAgent();
    error NotOwner();

    function poolsNFT() external view returns (IPoolsNFT);

    function isAgent(address account) external view returns (bool);

    function owner() external view returns (address);

    function setAgent(address _agent, bool _isAgent) external;

    function mint(
        uint16 strategyId,
        address quoteToken,
        address baseToken,
        uint256[] memory quoteTokenAmounts
    ) external returns (uint256[] memory poolIds);

    function mintTo(
        address receiver,   
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256[] memory quoteTokenAmounts
    ) external returns (uint256[] memory poolIds);

    function grind(uint256 poolId) external returns (bool);

    function batchGrind(uint256[] memory poolIds) external;

    function batchGrindOp(uint256[] memory poolIds, uint8[] memory ops) external;

    function setConfig(uint256 poolId, IURUS.Config memory config) external;

    function batchSetConfig(uint256[] memory poolIds, IURUS.Config[] memory configs) external;

    function setLongNumberMax(uint256 poolId, uint8 longNumberMax) external;

    function setHedgeNumberMax(uint256 poolId, uint8 hedgeNumberMax) external;

    function setExtraCoef(uint256 poolId, uint256 extraCoef) external;

    function setPriceVolatilityPercent(uint256 poolId, uint256 priceVolatilityPercent) external;

    function setOpReturnPercent(uint256 poolId, uint8 op, uint256 returnPercent) external;

    function setOpFeeCoef(uint256 poolId, uint8 op, uint256 _feeCoef) external;

    function execute(address target, uint256 value, bytes calldata data) external returns (bool success, bytes memory result);

}