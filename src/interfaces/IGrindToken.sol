// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "src/interfaces/IToken.sol";

interface IGrindToken is IToken {
    error NotGrindURUSPoolsNFT();
    error NotGrindURUSOwner();

    function grindURUSPoolsNFT() external view returns (address);

    function grinderReward() external view returns (uint256);

    function poolOwnerReward() external view returns (uint256);

    function royaltyReceiverReward() external view returns (uint256);

    function ownerReward() external view returns (uint256);

    function totalGrinds() external view returns (uint256);

    function rewardGrinder(address grinder) external returns (uint256);

    function rewardPoolOwner(address poolOwner) external returns (uint256);

    function rewardRoyaltyReceiver(address royaltyReceiver) external returns (uint256);

    function rewardTreasury(address treasury) external returns (uint256);

    function rewardOwner(address owner) external returns (uint256);
}
