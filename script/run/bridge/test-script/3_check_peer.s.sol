// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../../src/mTXToken/MTXToken.sol";

/// @title LayerZero OApp Peer Configuration Script
/// @notice Sets up peer connections between OApp deployments on different chains
contract SetPeers is Script {
    function run() external {
        // Load environment variables
        address oapp = vm.envAddress("OAPP_ADDRESS");         // Your OApp contract address

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Set peers for each chain
        bytes32 peer = MTXToken(oapp).peers(uint32(vm.envUint("CHAIN2_EID")));
        
        
        console.log(address(uint160(uint256(peer))));

        vm.stopBroadcast();
    }
}