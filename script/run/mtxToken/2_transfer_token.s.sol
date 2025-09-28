// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

contract MintToken is Script {
    function run() external {
        address tokenAddress = 0xc899BE3A96010435e55Aea5f53DB35a3AE8eBc9e;
        address userAddress = 0xe7A38d4d4D1ebc4e441f76a70AD7CE7a5D78531C;
        uint256 amountToMint = 1_000_000 * 10**18; // 1 million tokens

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MTXToken mtxToken = MTXToken(tokenAddress);
        
        // Mint tokens to user address
        mtxToken.mint(userAddress, amountToMint);

        console.log("Minted tokens to:", userAddress);
        console.log("Amount minted:", amountToMint);
        console.log("New balance:", mtxToken.balanceOf(userAddress));

        vm.stopBroadcast();
    }
}
