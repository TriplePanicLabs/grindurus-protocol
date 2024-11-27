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

    uint256 public totalGrinds;

    /// @dev actor address => total rewarded
    mapping(address actor => uint256) public totalRewarded;

    constructor(address _grindurusPoolsNFT) ERC20("GrindURUS Token", "GRIND") {
        grindURUSPoolsNFT = _grindurusPoolsNFT;
        /// initial rewards
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

    function reward(address[] memory actors, uint256[] memory rewards) public returns (uint256 totalReward) {
        _onlyGrindURUSPoolsNFT();
        if (actors.length != rewards.length) {
            return 0;
        }
        uint256 len = actors.length;
        uint256 i = 0;
        for (;i < len;) {
            if (rewards[i] > 0){
                _mint(actors[i], rewards[i]);
                totalReward += rewards[i];
            }
            unchecked {
                ++i;
            }
        }
        totalGrinds++;
    }
}
