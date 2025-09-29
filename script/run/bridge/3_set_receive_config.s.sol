// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

import { SetConfigParam } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";


import { UlnConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

/// @title LayerZero Receive Configuration Script (B ← A)
/// @notice Defines and applies ULN (DVN) config for inbound message verification on Chain B for messages received from Chain A via LayerZero Endpoint V2.
contract SetReceiveConfig is Script {
    uint32 constant RECEIVE_CONFIG_TYPE = 2;

    function _createRequiredDVNs() private pure returns (address[] memory) {
        address[] memory dvns = new address[](2);
        // DVN addresses must be sorted in ascending order
        dvns[0] = 0x3Ed2211f49ce343D70CB8dEd927cA6C4a6198101; // Smaller address first
        dvns[1] = 0x4f9D2bD7942c3e76CFC7323A56b95B4a6A52FdFd; // Larger address second
        
        return dvns;
    }

    function run() external {
        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");      // Chain B Endpoint
        address oapp      = vm.envAddress("OAPP_ADDRESS");         // OApp on Chain B
        uint32 eid        = uint32(vm.envUint("REMOTE_EID"));      // Endpoint ID for Chain A
        address receiveLib= vm.envAddress("RECEIVE_LIB_ADDRESS");  // ReceiveLib for B ← A
        address signer    = vm.envAddress("SIGNER");

        UlnConfig memory uln = UlnConfig({
            confirmations:      15,                                       // min block confirmations from source (A)
            requiredDVNCount:   2,                                        // required DVNs for message acceptance
            optionalDVNCount:   type(uint8).max,                          // optional DVNs count
            optionalDVNThreshold: 0,                                      // optional DVN threshold
            requiredDVNs:       _createRequiredDVNs(), // sorted required DVNs
            optionalDVNs:       new address[](0)                                        // no optional DVNs
        });

        bytes memory encodedUln = abi.encode(uln);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(eid, RECEIVE_CONFIG_TYPE, encodedUln);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params); // Set config for messages received on B from A
        
        vm.stopBroadcast();
    }
}