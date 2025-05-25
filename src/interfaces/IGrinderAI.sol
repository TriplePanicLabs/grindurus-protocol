// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IURUS } from "src/interfaces/IURUS.sol";
import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IPoolsNFTLens } from "src/interfaces/IPoolsNFTLens.sol";

interface IGrinderAI {

    struct Intent {
        address account;
        uint256 grinds;
        uint256[] poolIds;
        IPoolsNFTLens.PoolInfo[] poolInfos;
    }

    struct PnLShares {
        address receiver;
        uint256 grethAmount;
        uint256 graiAmount;
        uint256 baseTokenAmount;
        uint256 quoteTokenAmount;
    }

    error NotOwner();
    error NotConfigurator();
    error FailTransferETH();
    error InvalidLength();
    error NotPaymentToken();
    error NotMicroOp();
    error NotMacroOp();

    event Pay(address paymentToken, address payer, uint256 paymentAmount);

    function poolsNFT() external view returns (IPoolsNFT);

    function configurator() external view returns (address);

    function grinder() external view returns (address payable);
    
    function oneGRAI() external view returns (uint256);

    function ratePerGRAI(address paymentToken) external view returns (uint256);

    function crosschainAdapter(uint8 crosschainAdapterId) external view returns (address);

    function owner() external view returns (address);

    function setRatePerGRAI(address paymentToken, uint256 rate) external;

    function setConfigurator(address _configurator) external;
    
    function setCrosschainAdapter(uint8 id, address adapter) external;

    /// SETTING CONFIGS

    function checkLength(uint256 len0, uint256 len1) external view;
    function batchSetDexParams(uint256[] memory poolIds, bytes[] memory dexParams) external;
    function batchSetLendingParams(uint256[] memory poolIds, bytes[] memory lendingParams) external;
    function batchSetURUSConfig(uint256[] memory poolIds, IURUS.Config[] memory confs) external;
    function batchSetLongNumberMax(uint256[] memory poolIds, uint8[] memory longNumberMaxs) external;
    function batchSetHedgeNumberMax(uint256[] memory poolIds, uint8[] memory hedgeNumberMaxs) external;
    function batchSetExtraCoef(uint256[] memory poolIds, uint256[] memory extraCoefs) external;
    function batchSetPriceVolatilityPercent(uint256[] memory poolIds, uint256[] memory priceVolatilityPercents) external;
    function batchSetOpReturnPercent(uint256[] memory poolIds, uint8[] memory ops, uint256[] memory priceVolatilityPercents) external;
    function batchSetOpFeeCoef(uint256[] memory poolIds, uint8[] memory ops, uint256[] memory priceVolatilityPercents) external;

    function calcMintPayment(address paymentToken, uint256 graiAmount) external view returns (uint256 paymentAmount);

    function mint(address paymentToken, uint256 graiAmount) external payable returns (uint256);

    function mintTo(address paymentToken, address to, uint256 graiAmount) external payable returns (uint256);

    function grind(uint256 poolId) external returns (bool);

    function grindTo(uint256 poolId, address payable metaGrinder) external returns (bool);

    function batchGrind(uint256[] memory poolIds) external;

    function batchGrindTo(uint256[] memory poolIds, address payable metaGrinder) external;

    function grindOp(uint256 poolId, uint8 op) external returns (bool);

    function grindOpTo(uint256 poolId, uint8 op, address payable metaGrinder) external returns (bool);

    function batchGrindOp(uint256[] memory poolIds, uint8[] memory ops) external;

    function batchGrindOpTo(uint256[] memory poolIds, uint8[] memory ops, address payable metaGrinder) external;

    function microOp(uint256 poolId, uint8 op) external returns (bool success);

    function microOpTo(uint256 poolId, uint8 op, address payable metaGrinder) external returns (bool success);

    function macroOp(uint256 poolId, uint8 op) external returns (bool success);

    function macroOpTo(uint256 poolId, uint8 op, address payable metaGrinder) external returns (bool success);

    function getIntent(address account) external view returns (Intent memory intent);

    function getIntents(address[] memory accounts) external view returns (Intent[] memory intents);

    function getPnL(uint256 poolId) external view returns (IURUS.PnL memory) ;

    function getPnLBy(uint256[] memory poolIds) external view returns (IURUS.PnL[] memory pnls);

    function getPnLShares(uint256 poolId) external view returns (PnLShares[] memory pnlShares);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function withdraw(address token, uint256 amount) external returns (uint256);

    function withdrawTo(address token, address to, uint256 amount) external returns (uint256 withdrawn);

    function execute(address target, uint256 value, bytes memory data) external payable returns (bool success, bytes memory result);

}