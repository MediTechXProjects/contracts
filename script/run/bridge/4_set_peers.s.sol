// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

/// @title LayerZero OApp Peer Configuration Script
/// @notice Sets up peer connections between OApp deployments on different chains
contract SetPeers is Script {
    function run() external {
        // Load environment variables
        address oapp = vm.envAddress("OAPP_ADDRESS");         // Your OApp contract address
        address signer = vm.envAddress("SIGNER");            // Address with owner permissions

        // Example: Set peers for different chains
        // Format: (chain EID, peer address in bytes32)
        (uint32 eid1, bytes32 peer1) = (uint32(vm.envUint("CHAIN1_EID")), bytes32(uint256(uint160(vm.envAddress("CHAIN1_PEER")))));
        (uint32 eid2, bytes32 peer2) = (uint32(vm.envUint("CHAIN2_EID")), bytes32(uint256(uint160(vm.envAddress("CHAIN2_PEER")))));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Set peers for each chain
        MTXToken(oapp).setPeer(eid1, peer1);
        MTXToken(oapp).setPeer(eid2, peer2);

        vm.stopBroadcast();
    }
}