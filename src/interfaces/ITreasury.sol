// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ITreasury {
    error NotOwner();
    error NotPoolsNFT();
    error InvalidFeeNumerator();
    event FailExecute();

    function poolsNFT() external view returns (address);

    function feeReceiver() external view returns (address payable);

    function feeNumerator() external view returns (uint16);

    function setFeeNumerator(uint16 _feeNumerator) external;

    function onGrind(uint256 poolId) external;

    function onBuyRoyalty(uint256 poolId) external;

    function execute(address payable target, uint256 value, bytes calldata data) external;
}
