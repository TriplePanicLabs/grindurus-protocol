// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { OFT, ERC20 } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { IGRAI, MessagingFee, SendParam } from "src/interfaces/IGRAI.sol";
import { IGrinderAI } from "src/interfaces/IGrinderAI.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/// @title GRAI
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice GrinderAI ERC20 token
/// @dev Omni Fungible Token for crosschain bridging and interoperability.
contract GRAI is IGRAI, OFT {
    /// @dev 100% = 100_00
    uint256 public constant DENOMINATOR = 100_00;

    /// @dev address of grinderAI 
    IGrinderAI public grinderAI;

    /// @dev numerator of multiplier
    uint256 public multiplierNumerator;

    /// @dev numerator of native bridge fee percent
    /// @dev layer zero endpoint id => fee numerator
    mapping (uint32 endpointId => uint256) public artificialFeeNumerator;

    /// @dev endpoint id => tuple of bridge gas limit and value
    mapping (uint32 endpointId => LzReceiveOptions) public lzReceiveOptions;

    /// @param _lzEndpoint address of layer zero endpoint
    /// @param _grinderAI address of grinderAI
    constructor(address _lzEndpoint, address _grinderAI) OFT("GrinderAI Token", "grAI", _lzEndpoint, _grinderAI) Ownable(_grinderAI) {
        grinderAI = IGrinderAI(_grinderAI);
        multiplierNumerator = DENOMINATOR; // x1.0
        /// default bridge gas limit and value for EVM chains
        uint32 defaultEndpointId = 0;
        artificialFeeNumerator[defaultEndpointId] = 0; 
        lzReceiveOptions[defaultEndpointId] = LzReceiveOptions({
            gasLimit: 100_000,
            value: 0
        });
    }

    /// @notice check that msg.sender is grinderAI
    function _onlyGrinderAI() private view {
        if (msg.sender != address(grinderAI)) {
            revert NotGrinderAI();
        }
    }

    /// @notice balance of grAI
    function balanceOf(address account) public view override(ERC20, IGRAI) returns (uint256) {
        return ERC20.balanceOf(account);
    }

    //// CONFIGURATION OF BRIDGE OPTIONS ////

    /// @notice sets bridge gas limit and value
    /// @param gasLimit gas limit for the bridge
    /// @param value value for the bridge
    function setLzReceivOptions(uint32 endpointId, uint128 gasLimit, uint128 value) public override {
        _onlyGrinderAI();
        lzReceiveOptions[endpointId] = LzReceiveOptions({
            gasLimit: gasLimit,
            value: value
        });
    }

    /// @notice sets multiplier numerator
    /// @param _multiplierNumerator numerator of multiplier
    function setMultiplierNumerator(uint256 _multiplierNumerator) public override {
        _onlyGrinderAI();
        multiplierNumerator = _multiplierNumerator;
    }

    /// @notice sets bridge fee numerator. surplused to estimate
    /// @dev 100% = 100_00
    /// @param _artificialFeeNumerator numerator of bridge fee
    function setArtificialFeeNumerator(uint32 endpointId, uint256 _artificialFeeNumerator) public override {
        _onlyGrinderAI();
        artificialFeeNumerator[endpointId] = _artificialFeeNumerator;
    }

    /// @notice sets peer address
    /// @param eid id of the peer
    /// @param peer address of the peer
    function setPeer(uint32 eid, bytes32 peer) public override(IGRAI, OAppCore) {
        _onlyGrinderAI();
        _setPeer(eid, peer);
    }

    /// @notice mints amount of grAI to `to`
    /// @dev callable only by grinderAI
    /// @param to address to mint to
    /// @param amount amount of grAI to mint
    function mint(address to, uint256 amount) public override returns (uint256) {
        _onlyGrinderAI();
        _mint(to, amount);
        return amount;
    }

    /// @notice transmit grAI for grind from `from` to `to  
    /// @dev callable only by grinderAI
    function transmit(address from, address to, uint256 amount) public override returns (uint256) {
        _onlyGrinderAI();
        if (balanceOf(from) < amount) {
            return 0;
        }
        _transfer(from, to, amount);
        return amount;
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IGRAI) returns (bool) {
        return ERC20.transferFrom(from, to, amount);
    }

    /// @notice direct transfer grAI
    /// @param to address of to
    /// @param amount amount of grAI
    function transfer(address to, uint256 amount) public override(ERC20, IGRAI) returns (bool) {
        return ERC20.transfer(to, amount);
    }

    /// @notice Bridges GRAI tokens to another chain
    /// @param dstChainId ID of the destination chain (LayerZero chain ID)
    /// @param toAddress Address of the recipient on the destination chain
    /// @param amount Amount of GRAI tokens to bridge
    function bridgeTo(
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount
    ) public payable override {
        SendParam memory sendParam = formSendParamsForBridgeTo(
            dstChainId,
            toAddress,
            amount
        );
        MessagingFee memory fee = formMessagingFeeForBridgeTo(sendParam);
        (   
            uint256 nativeFee,      // nativeFee = fee.nativeFee * multiplierNumerator / DENOMINATOR
            uint256 artificialFee,  // artificialFee = grinderAI.calcPayment(address(0), amount) * artificialFeeNumerator[dstChainId] / DENOMINATOR
            uint256 totalFee        // totalFee = nativeFee + artificialFee
        ) = getTotalFees(dstChainId, toAddress, amount);
        if (totalFee < msg.value) {
            revert InsufficientNativeFee();
        }
        if (artificialFee > 0) {
            (bool success, bytes memory result) = address(grinderAI).call{value: artificialFee}("");
            success; result;
        }
        _transfer(msg.sender, address(this), amount);
        this.send{value: nativeFee}(sendParam, fee, msg.sender);
        emit Bridge(
            msg.sender,
            dstChainId,
            toAddress,
            amount,
            nativeFee,
            artificialFee
        );
    }

    /// @notice Forms the parameters for bridging to another chain
    /// @param dstChainId ID of the destination chain (LayerZero chain ID)
    /// @param toAddress Address of the recipient on the destination chain
    /// @param amount Amount of GRAI tokens to bridge
    function formSendParamsForBridgeTo(
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount
    ) public view override returns (SendParam memory sendParam) {
        (uint128 gasLimit, uint128 value) = getLzReceiveOptions(dstChainId);
        bytes memory options = OptionsBuilder.newOptions();
        options = OptionsBuilder.addExecutorLzReceiveOption(options, gasLimit, value);
        sendParam = SendParam({
            dstEid: dstChainId,
            to: toAddress,
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });
    }

    /// @notice Forms the parameters for bridging to another chain
    /// @param sendParam SendParam struct
    function formMessagingFeeForBridgeTo(SendParam memory sendParam) public view override returns (MessagingFee memory) {
        return this.quoteSend(sendParam, false);
    }
    
    /// @notice Estimates the total fee for bridging to another chain
    /// @param dstChainId ID of the destination chain (LayerZero chain ID)
    /// @param toAddress Address of the recipient on the destination chain
    /// @param amount Amount of GRAI tokens to bridge
    function getTotalFees(
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount
    ) public view override returns (
        uint256 nativeFee, 
        uint256 artificialFee, 
        uint256 totalFee
    ) {
        nativeFee = estimateBridgeFee(
            dstChainId, 
            toAddress, 
            amount
        );
        artificialFee = calcArtificialFee(dstChainId, amount);
        totalFee = nativeFee + artificialFee;
    }

    /// @notice estimates bridge fee
    /// @param dstChainId ID of the destination chain (LayerZero chain ID)
    /// @param toAddress Address of the recipient on the destination chain
    /// @param amount Amount of GRAI tokens to bridge
    function estimateBridgeFee(
        uint32 dstChainId,
        bytes32 toAddress,
        uint256 amount
    ) public view override returns (uint256 nativeFee) {
        SendParam memory sendParam = formSendParamsForBridgeTo(
            dstChainId,
            toAddress,
            amount
        );
        MessagingFee memory fee = formMessagingFeeForBridgeTo(sendParam);
        nativeFee = (fee.nativeFee * multiplierNumerator) / DENOMINATOR;
    }

    /// @notice calculates bridge fee
    /// @param dstChainId ID of the destination chain (LayerZero chain ID)
    /// @param amount amount of GRAI tokens to bridge
    function calcArtificialFee(uint32 dstChainId, uint256 amount) public view override returns (uint256) {
        try grinderAI.calcPayment(address(0), amount) returns (uint256 paymentAmount) {
            return (paymentAmount * artificialFeeNumerator[dstChainId]) / DENOMINATOR;
        } catch {
            return 0;
        }
    }

    /// @notice gets bridge gas limit and value
    /// @param endpointId id of the endpoint
    function getLzReceiveOptions(uint32 endpointId) public view returns (uint128 gasLimit, uint128 value) {
        LzReceiveOptions memory options = lzReceiveOptions[endpointId];
        if (options.gasLimit > 0) {
            gasLimit = options.gasLimit;
            value = options.value;
        } else {
            LzReceiveOptions memory defaultOptions = lzReceiveOptions[0];
            gasLimit = defaultOptions.gasLimit;
            value = defaultOptions.value;
        }
    }

    /// @notice converts address to bytes32
    /// @param addr address to convert to bytes32
    function addressToBytes32(address addr) public pure override returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
    
    /// @notice converts bytes32 to address
    /// @param b bytes32 to convert to address
    function bytes32ToAddress(bytes32 b) public pure override returns (address) {
        return address(uint160(uint256(b)));
    }

    /// @notice execute any transaction on target smart contract
    /// @dev callable only by owner
    /// @param target address of target contract
    /// @param value amount of ETH
    /// @param data data to execute on target contract
    function execute(address target, uint256 value, bytes memory data) public payable virtual override returns (bool success, bytes memory result) {
        _onlyGrinderAI();
        (success, result) = target.call{value: value}(data);
    }

    receive() external payable {
        if (msg.value > 0) {
            bool success;
            (success, ) = address(grinderAI).call{value: msg.value}("");
        }
    }

}