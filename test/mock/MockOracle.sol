// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IOracle } from "src/interfaces/IOracle.sol";

interface IMockSwapRouter {

    function rateTokenInByTokenOut() external view returns (uint256);

    function rateDecimals() external view returns (uint8);

}

contract MockOracle is IOracle {

    IMockSwapRouter public mockSwapRouter;

    constructor (address _mockSwapRouter) {
        mockSwapRouter = IMockSwapRouter(_mockSwapRouter);
    }

    function decimals() external view returns (uint8) {
        return mockSwapRouter.rateDecimals();
    }

    function description() external view returns (string memory) {
        return "mock oracle";
    }

    function version() external view returns (uint256) {
        return 0;
    }

    function latestRoundData() external view
        returns (
            uint80,
            int256 answer,
            uint256,
            uint256,
            uint80
        ) 
    {
        answer = int256(mockSwapRouter.rateTokenInByTokenOut());
    }


}