// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IOracle } from "src/interfaces/IOracle.sol";

contract PriceOracleInverse is IOracle {

    IOracle public oracle;

    uint8 public originDecimals;

    constructor (address _oracle) {
        if (_oracle != address(0)) {
            oracle = IOracle(_oracle);
            originDecimals = oracle.decimals();
        }
    }

    function decimals() public view returns (uint8) {
        return originDecimals + 4;
    }

    function description() public view returns (string memory) {
        string memory _description = oracle.description();
        return string.concat("Inverse ", _description);
    }

    function version() public view returns (uint256) {
        return oracle.version();
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) 
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = oracle.latestRoundData();
        answer = int256(10 ** (originDecimals + decimals()) / uint256(answer)); 
    }

}
