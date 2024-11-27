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

    /// @notice reward to treasury
    uint256 public treasuryReward;

    /// @notice reward to owner of grindurus protocol for his blessed mind
    uint256 public ownerReward;

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
        treasuryReward = 1 * 1e18;
        ownerReward = 0.005 * 1e18;
        totalGrinds = 0;
    }

    /// @notice checks that msg.sender is grindurus pools NFT
    function _onlyGrindURUSPoolsNFT() private view {
        if (msg.sender != grindURUSPoolsNFT) {
            revert NotGrindURUSPoolsNFT();
        }
    }

    /// @notice check that msg.sender is grindURUS owner
    function _onlyOwner() private view {
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
        _onlyOwner();
        grinderReward = _grinderReward;
    }

    /// @notice sets pool owner reward
    /// @param _poolOwnerReward new pool owner reward in terms of GRIND token
    function setPoolOwnerReward(uint256 _poolOwnerReward) public {
        _onlyOwner();
        poolOwnerReward = _poolOwnerReward;
    }

    /// @notice sets royalty receiver reward
    /// @param _royaltyReceiverReward new royalty receiver reward in terms of GRIND token
    function setRoyaltyReceiverReward(uint256 _royaltyReceiverReward) public {
        _onlyOwner();
        royaltyReceiverReward = _royaltyReceiverReward;
    }

    /// @notice sets grindURUS owner reward
    /// @param _ownerReward new grindURUS owner reward in terms of GRIND token
    function setOwnerReward(uint256 _ownerReward) public {
        _onlyOwner();
        ownerReward = _ownerReward;
    }

    /// @notice rewards grinder for grinding
    /// @dev callable by grindurus pools NFT
    /// @param grinder address of grinder, that will receive GRIND reward
    function rewardGrinder(address grinder) public returns (uint256) {
        _onlyGrindURUSPoolsNFT();
        _mint(grinder, grinderReward);
        totalRewarded[grinder] += grinderReward;
        totalGrinds++;
        return grinderReward;
    }

    /// @notice rewards pool owner for holding funds in protocol
    /// @dev callable by grindurus pools NFT
    /// @param poolOwner address of pool owner, that will receive GRIND reward
    function rewardPoolOwner(address poolOwner) public returns (uint256) {
        _onlyGrindURUSPoolsNFT();
        _mint(poolOwner, poolOwnerReward);
        totalRewarded[poolOwner] += poolOwnerReward;
        return poolOwnerReward;
    }

    /// @notice rewards royalty receiver for oppotunity to buy royalty
    /// @dev callable by grindurus pools NFT
    /// @param royaltyReceiver address of royalty receiver, that will receive GRIND reward
    function rewardRoyaltyReceiver(address royaltyReceiver) public returns (uint256) {
        _onlyGrindURUSPoolsNFT();
        _mint(royaltyReceiver, royaltyReceiverReward);
        totalRewarded[royaltyReceiver] += royaltyReceiverReward;
        return royaltyReceiverReward;
    }

    function rewardTreasury(address treasury) public returns (uint256) {
        _onlyGrindURUSPoolsNFT();
        _mint(treasury, treasuryReward);
        return treasuryReward;
    }

    /// @notice rewards royalty receiver for oppotunity to buy royalty
    /// @dev callable by grindURUS pools NFT
    function rewardOwner(address owner) public returns (uint256) {
        _onlyGrindURUSPoolsNFT();
        _mint(owner, ownerReward);
        totalRewarded[owner] += ownerReward;
        return ownerReward;
    }
}
