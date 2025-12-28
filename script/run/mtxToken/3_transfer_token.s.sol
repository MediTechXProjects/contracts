// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

contract TransferToken is Script {
    function run() external {
        address tokenAddress = 0x5d67d0efD22ab2Aa718FA34a9B63330862B6482c;
        address userAddress = 0xe7A38d4d4D1ebc4e441f76a70AD7CE7a5D78531C;
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
