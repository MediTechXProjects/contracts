// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

contract TransferToken is Script {
    function run() external {
        address tokenAddress = 0x5d67d0efD22ab2Aa718FA34a9B63330862B6482c;
        address userAddress = 0x9889cf81bb4bD51C0992183BFE837D3163971356;
        uint256 amountToTransfer = 100_000 * 10**18; // 1 million tokens

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
