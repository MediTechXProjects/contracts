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
        dvns[0] = 0x68802e01D6321D5159208478f297d7007A7516Ed; // Smaller address first
        dvns[1] = 0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193; // Larger address second
        
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
            executor: 0x718B92b5CB0a5552039B593faF724D182A881eDA                           // address that pays destination execution fees on B
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