// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IAAVEV3PoolArbitrum} from "src/interfaces/aaveV3/IAAVEV3PoolArbitrum.sol";

contract MockAAVEV3PoolArbitrum is IAAVEV3PoolArbitrum {

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) public {

    }

    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) public {

    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {

    }

    function getReserveData(
        address asset
    ) external view returns (ReserveData memory) {
        
    }

}