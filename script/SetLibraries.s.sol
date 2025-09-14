// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/// @title LayerZero Library Configuration Script
/// @notice Sets up send and receive libraries for OApp messaging
contract SetLibraries is Script {
    function run() external {
        // Load environment variables
        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");    // LayerZero Endpoint address
        address oapp = vm.envAddress("OAPP_ADDRESS");           // Your OApp contract address
        address signer = vm.envAddress("SIGNER");               // Address with permissions to configure

        console.log("endpoint  :  ", endpoint);
        console.log("oapp  :  ", oapp);
        console.log("signer  :  ", signer);

        // Library addresses
        address sendLib = vm.envAddress("SEND_LIB_ADDRESS");    // SendUln302 address
        address receiveLib = vm.envAddress("RECEIVE_LIB_ADDRESS"); // ReceiveUln302 address

        console.log("sendLib  :  ", sendLib);
        console.log("receiveLib  :  ", receiveLib);

        // Chain configurations
        uint32 dstEid = uint32(vm.envUint("DST_EID"));         // Destination chain EID
        uint32 srcEid = uint32(vm.envUint("SRC_EID"));         // Source chain EID
        uint32 gracePeriod = uint32(vm.envUint("GRACE_PERIOD")); // Grace period for library switch

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Set send library for outbound messages
        ILayerZeroEndpointV2(endpoint).setSendLibrary(
            oapp,    // OApp address
            dstEid,  // Destination chain EID
            sendLib  // SendUln302 address
        );

        // Set receive library for inbound messages
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(
            oapp,        // OApp address
            srcEid,      // Source chain EID
            receiveLib,  // ReceiveUln302 address
            gracePeriod  // Grace period for library switch
        );

        vm.stopBroadcast();
    }
}