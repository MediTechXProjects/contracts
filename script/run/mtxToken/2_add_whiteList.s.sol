// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

contract AddWhitelist is Script {
    function run() external {
        address tokenAddress = 0x5d67d0efD22ab2Aa718FA34a9B63330862B6482c;

        // Addresses to add to whitelist
        address[] memory addressesToWhitelist = new address[](1);
        addressesToWhitelist[0] = 0xB8ac0b0b9422718A382786d7b237b3011ae99F4b; // Replace with actual address

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MTXToken mtxToken = MTXToken(tokenAddress);
        
        // Add addresses to whitelist
        for (uint256 i = 0; i < addressesToWhitelist.length; i++) {
            mtxToken.addToWhitelist(addressesToWhitelist[i]);
            console.log("Added to whitelist:", addressesToWhitelist[i]);
        }
        
        console.log("Whitelist operation completed for token:", tokenAddress);

        vm.stopBroadcast();
    }
}
