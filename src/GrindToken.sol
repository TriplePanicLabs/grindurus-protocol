// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IGrindToken} from "./interfaces/IGrindToken.sol";
import {IGrindURUSPoolsNFT} from "./interfaces/IGrindURUSPoolsNFT.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title GrindToken
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice incentivization token for grinding the strategy
contract GrindToken is IGrindToken, ERC20 {
    /// @dev address of grindurus strategy positions NFT
    address public grindurusPoolsNFT;

    /// @notice reward to grinder for grind
    uint256 public grinderReward;

    /// @notice reward to pool owner for holding funds on grindurus platform
    uint256 public poolOwnerReward;

    /// @notice reward to royalty receiver of pool strategy
    uint256 public royaltyReceiverReward;

    /// @notice reward to owner of grindurus protocol for his blessed mind
    uint256 public ownerReward;

    /// @notice total amount of call grind
    uint256 public totalGrinds;

    /// @dev actor address => total rewarded
    mapping(address actor => uint256) public totalRewarded;

    constructor(address _grindurusPoolsNFT) ERC20("GrindURUS Token", "GRIND") {
        grindurusPoolsNFT = _grindurusPoolsNFT;
        grinderReward = 1 * 1e18;
        poolOwnerReward = 0.02 * 1e18;
        royaltyReceiverReward = 0.01 * 1e18;
        ownerReward = 0.005 * 1e18;
        totalGrinds = 0;
    }

    /// @notice checks that msg.sender is grindurus pools NFT
    function _onlyGrindurusPoolsNFT() private view {
        if (msg.sender != grindurusPoolsNFT) {
            revert NotGrindURUSPoolsNFT();
        }
    }

    /// @notice rewards grinder for grinding
    /// @dev callable by grindurus pools NFT
    /// @param grinder address of grinder, that will receive GRIND reward
    function rewardGrinder(address grinder) public {
        _onlyGrindurusPoolsNFT();
        _mint(grinder, grinderReward);
        totalRewarded[grinder] += grinderReward;
        totalGrinds++;
    }

    /// @notice rewards pool owner for holding funds in protocol
    /// @dev callable by grindurus pools NFT
    /// @param poolOwner address of pool owner, that will receive GRIND reward
    function rewardPoolOwner(address poolOwner) public {
        _onlyGrindurusPoolsNFT();
        _mint(poolOwner, poolOwnerReward);
        totalRewarded[poolOwner] += poolOwnerReward;
    }

    /// @notice rewards royalty receiver for oppotunity to buy royalty
    /// @dev callable by grindurus pools NFT
    /// @param royaltyReceiver address of royalty receiver, that will receive GRIND reward
    function rewardRoyaltyReceiver(address royaltyReceiver) public {
        _onlyGrindurusPoolsNFT();
        _mint(royaltyReceiver, royaltyReceiverReward);
        totalRewarded[royaltyReceiver] += royaltyReceiverReward;
    }

    /// @notice rewards royalty receiver for oppotunity to buy royalty
    /// @dev callable by grindurus pools NFT
    /// @param owner address of royalty receiver, that will receive GRIND reward
    function rewardOwner(address owner) public {
        _onlyGrindurusPoolsNFT();
        _mint(owner, ownerReward);
        totalRewarded[owner] += ownerReward;
    }
}
