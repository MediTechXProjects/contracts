// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { IMTXPresale } from "./../../../src/presale/IMTXPresale.sol";

contract ClaimToken is Script {
    function run() external {
        // Set the presale contract address
        address presaleAddress = 0xAc6eB4E9F8519DCb6819bDF84248F4901E5eFb6b;
        
        // Get the user address (can be from env or use msg.sender)
        address userAddress = vm.envOr("USER_ADDRESS", vm.addr(vm.envUint("PRIVATE_KEY")));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IMTXPresale presale = IMTXPresale(presaleAddress);

        // Get user's purchase information before claiming
        uint256 totalPurchased = presale.getUserTotalPurchased(userAddress);
        uint256 claimedBalance = presale.getUserClaimedBalance(userAddress);
        uint256 lockedBalance = presale.getUserLockedBalance(userAddress);

        console.log("=== Before Claim ===");
        console.log("User address:", userAddress);
        console.log("Total purchased:", totalPurchased);
        console.log("Already claimed:", claimedBalance);
        console.log("Locked balance:", lockedBalance);

        // Claim tokens
        presale.claimTokens();

        // Get user's information after claiming
        uint256 newClaimedBalance = presale.getUserClaimedBalance(userAddress);
        uint256 newLockedBalance = presale.getUserLockedBalance(userAddress);
        uint256 claimedAmount = newClaimedBalance - claimedBalance;

        console.log("=== After Claim ===");
        console.log("Claimed amount:", claimedAmount);
        console.log("New claimed balance:", newClaimedBalance);
        console.log("New locked balance:", newLockedBalance);

        vm.stopBroadcast();
    }
}

