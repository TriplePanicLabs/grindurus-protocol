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
    address public grindURUSPoolsNFT;

    /// @notice reward to grinder for grind
    uint256 public grinderReward;

    /// @notice reward to pool owner for holding funds on grindurus platform
    uint256 public poolOwnerReward;

    /// @notice reward to royalty receiver of pool strategy
    uint256 public royaltyReceiverReward;

    /// @notice reward to owner of grindurus protocol for his blessed mind
    uint256 public grindURUSOwnerReward;

    /// @notice total amount of call grind
    uint256 public totalGrinds;

    /// @dev actor address => total rewarded
    mapping(address actor => uint256) public totalRewarded;

    constructor(address _grindurusPoolsNFT) ERC20("GrindURUS Token", "GRIND") {
        grindURUSPoolsNFT = _grindurusPoolsNFT;
        /// initial rewards
        grinderReward = 1 * 1e18;
        poolOwnerReward = 0.02 * 1e18;
        royaltyReceiverReward = 0.01 * 1e18;
        grindURUSOwnerReward = 0.005 * 1e18;
        totalGrinds = 0;
    }

    /// @notice checks that msg.sender is grindurus pools NFT
    function _onlyGrindurusPoolsNFT() private view {
        if (msg.sender != grindURUSPoolsNFT) {
            revert NotGrindURUSPoolsNFT();
        }
    }

    /// @notice check that msg.sender is grindURUS owner
    function _onlyGrindURUSOwner() private view {
        address owner;
        try IGrindURUSPoolsNFT(grindURUSPoolsNFT).owner() returns (address payable _owner) {
            owner = _owner;
        } catch {
            owner = grindURUSPoolsNFT;
        }
        if (msg.sender != owner) {
            revert NotGrindURUSOwner();
        }
    }

    /// @notice sets grinder reward
    /// @param _grinderReward new grinder reward in terms of GRIND token
    function setGrinderReward(uint256 _grinderReward) public {
        _onlyGrindURUSOwner();
        grinderReward = _grinderReward;
    }

    /// @notice sets pool owner reward
    /// @param _poolOwnerReward new pool owner reward in terms of GRIND token
    function setPoolOwnerReward(uint256 _poolOwnerReward) public {
        _onlyGrindURUSOwner();
        poolOwnerReward = _poolOwnerReward;
    }

    /// @notice sets royalty receiver reward
    /// @param _royaltyReceiverReward new royalty receiver reward in terms of GRIND token
    function setRoyaltyReceiverReward(uint256 _royaltyReceiverReward) public {
        _onlyGrindURUSOwner();
        royaltyReceiverReward = _royaltyReceiverReward;
    }

    /// @notice sets grindURUS owner reward
    /// @param _grindURUSOwnerReward new grindURUS owner reward in terms of GRIND token
    function setGrindURUSOwnerReward(uint256 _grindURUSOwnerReward) public {
        _onlyGrindURUSOwner();
        grindURUSOwnerReward = _grindURUSOwnerReward;
    }

    /// @notice rewards grinder for grinding
    /// @dev callable by grindurus pools NFT
    /// @param grinder address of grinder, that will receive GRIND reward
    function rewardGrinder(address grinder) public returns (uint256) {
        _onlyGrindurusPoolsNFT();
        _mint(grinder, grinderReward);
        totalRewarded[grinder] += grinderReward;
        totalGrinds++;
        return grinderReward;
    }

    /// @notice rewards pool owner for holding funds in protocol
    /// @dev callable by grindurus pools NFT
    /// @param poolOwner address of pool owner, that will receive GRIND reward
    function rewardPoolOwner(address poolOwner) public returns (uint256) {
        _onlyGrindurusPoolsNFT();
        _mint(poolOwner, poolOwnerReward);
        totalRewarded[poolOwner] += poolOwnerReward;
        return poolOwnerReward;
    }

    /// @notice rewards royalty receiver for oppotunity to buy royalty
    /// @dev callable by grindurus pools NFT
    /// @param royaltyReceiver address of royalty receiver, that will receive GRIND reward
    function rewardRoyaltyReceiver(address royaltyReceiver) public returns (uint256) {
        _onlyGrindurusPoolsNFT();
        _mint(royaltyReceiver, royaltyReceiverReward);
        totalRewarded[royaltyReceiver] += royaltyReceiverReward;
        return royaltyReceiverReward;
    }

    /// @notice rewards royalty receiver for oppotunity to buy royalty
    /// @dev callable by grindURUS pools NFT
    function rewardGrindURUSOwner() public returns (uint256) {
        _onlyGrindurusPoolsNFT();
        address grindURUSOwner = IGrindURUSPoolsNFT(grindURUSPoolsNFT).owner();
        _mint(grindURUSOwner, grindURUSOwnerReward);
        totalRewarded[grindURUSOwner] += grindURUSOwnerReward;
        return grindURUSOwnerReward;
    }
}
