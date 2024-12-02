// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IGRETH} from "./interfaces/IGRETH.sol";
import {IPoolsNFT} from "./interfaces/IPoolsNFT.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title GRETH
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice incentivization token for grinding the strategy
contract GRETH is IGRETH, ERC20 {
    /// @dev address of grindurus strategy positions NFT
    address public poolsNFT;

    uint256 public totalGrinds;

    /// @dev actor address => total rewarded
    mapping(address actor => uint256) public totalMinted;

    constructor(address _poolsNFT) ERC20("GrindURUS ETH", "grETH") {
        if (_poolsNFT != address(0)) {
            poolsNFT = _poolsNFT;
        } else {
            poolsNFT == msg.sender;
        }
        totalGrinds = 0;
    }

    /// @notice checks that msg.sender is grindurus pools NFT
    function _onlyPoolsNFT() private view {
        if (msg.sender != poolsNFT) {
            revert NotGrindURUSPoolsNFT();
        }
    }

    /// @notice mint GRETH to actors.
    /// @dev callable only by `poolsNFT`
    function mint(
        address[] memory actors,
        uint256[] memory shares
    ) public returns (uint256 totalShares) {
        _onlyPoolsNFT();
        if (actors.length != shares.length) {
            return 0;
        }
        uint256 len = actors.length;
        uint256 i = 0;
        for (; i < len; ) {
            if (shares[i] > 0) {
                _mint(actors[i], shares[i]);
                totalMinted[actors[i]] += shares[i];
                totalShares += shares[i];
            }
            unchecked {
                ++i;
            }
        }
        unchecked {
            totalGrinds++;
        }
    }
}
