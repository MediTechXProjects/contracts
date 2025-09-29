// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

import { SetConfigParam } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import { UlnConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import { ExecutorConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

contract SetSendConfig is Script {
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;

    function _createRequiredDVNs() private pure returns (address[] memory) {
        address[] memory dvns = new address[](2);
        // DVN addresses must be sorted in ascending order
        dvns[0] = 0x3Ed2211f49ce343D70CB8dEd927cA6C4a6198101; // Smaller address first
        dvns[1] = 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6; // Larger address second
        
        return dvns;
    }

    function run() external {
        address endpoint = vm.envAddress("SOURCE_ENDPOINT_ADDRESS"); 
        address oapp      = vm.envAddress("SENDER_OAPP_ADDRESS");    
        uint32 eid        = uint32(vm.envUint("REMOTE_EID"));        
        address sendLib   = vm.envAddress("SEND_LIB_ADDRESS"); 
        address signer    = vm.envAddress("SIGNER");

        UlnConfig memory uln = UlnConfig({
            confirmations:        15,                                      // minimum block confirmations required on A before sending to B
            requiredDVNCount:     2,                                       // number of DVNs required
            optionalDVNCount:     type(uint8).max,                         // optional DVNs count, uint8
            optionalDVNThreshold: 0,                                       // optional DVN threshold
            requiredDVNs: _createRequiredDVNs(),
            optionalDVNs: new address[](0)  
        });

        /// @notice ExecutorConfig sets message size limit + fee‑paying executor for A → B
        ExecutorConfig memory exec = ExecutorConfig({
            maxMessageSize: 10000,                                       // max bytes per cross-chain message
            executor: 0x8A3D588D9f6AC041476b094f97FF94ec30169d3D                           // address that pays destination execution fees on B
        });

        bytes memory encodedUln  = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);

        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid, ULN_CONFIG_TYPE, encodedUln);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params); // Set config for messages sent from A to B
        
        vm.stopBroadcast();
    }
}