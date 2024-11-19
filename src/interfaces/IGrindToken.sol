// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "src/interfaces/IToken.sol";

interface IGrindToken is IToken {

    error NotGrindURUSPoolsNFT();

    function grindurusPoolsNFT() external view returns (address);

    function grinderReward() external view returns (uint256);

    function poolOwnerReward() external view returns (uint256);

    function royaltyReceiverReward() external view returns (uint256);

    function ownerReward() external view returns (uint256);

    function totalGrinds() external view returns (uint256);
    
    function rewardGrinder(address grinder) external;

    function rewardPoolOwner(address poolOwner) external;

    function rewardRoyaltyReceiver(address royaltyReceiver) external;

    function rewardOwner(address owner) external;

}