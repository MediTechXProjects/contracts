// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MEXToken } from "./../../../src/mEXToken/MEXToken.sol";

contract AddWhitelist is Script {
    function run() external {
        address tokenAddress = 0x3d9BdbD24D202fAAaE61CEdD7e5a70A9a62d0879;

        // Addresses to add to whitelist
        address[] memory addressesToWhitelist = new address[](1);
        addressesToWhitelist[0] = 0x70ef22303a0446A620a1f66169aE5E08E1107aCe;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MEXToken mexToken = MEXToken(tokenAddress);
        
        // Add addresses to whitelist
        for (uint256 i = 0; i < addressesToWhitelist.length; i++) {
            mexToken.addToWhitelist(addressesToWhitelist[i]);
            console.log("Added to whitelist:", addressesToWhitelist[i]);
        }
        
        console.log("Whitelist operation completed for token:", tokenAddress);

        vm.stopBroadcast();
    }
}
