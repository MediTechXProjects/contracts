// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

contract TransferToken is Script {
    function run() external {
        address tokenAddress = 0xc899BE3A96010435e55Aea5f53DB35a3AE8eBc9e;
        address userAddress = 0xB71a4183035b75b89a65380C0E8965fbf5101341;
        uint256 amountToTransfer = 1_000_000 * 10**18; // 1 million tokens

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MTXToken mtxToken = MTXToken(tokenAddress);
        
        // Mint tokens to user address
        mtxToken.transfer(userAddress, amountToTransfer);

        console.log("Minted tokens to:", userAddress);
        console.log("Amount transferred:", amountToTransfer);
        console.log("New to balance:", mtxToken.balanceOf(userAddress));

        vm.stopBroadcast();
    }
}
