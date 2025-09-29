// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { MTXToken } from "./../../../../src/mTXToken/MTXToken.sol";

contract CheckSupported is Script {
    function run() external {
        // Load environment variable for Amoy endpoint
        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address addr = vm.envAddress("OAPP_ADDRESS");

        
        MTXToken oapp = MTXToken(addr);


        uint32 dstEid = uint32(vm.envUint("DST_EID"));


        bool supported = ILayerZeroEndpointV2(endpoint).isSupportedEid(dstEid);

        console.log("OApp owner:", oapp.owner());

        console.log("DST_EID:", dstEid, "supported?", supported);

    }
}
