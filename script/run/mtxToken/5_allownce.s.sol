// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

contract GiveAllowance is Script {
    function run() external {
        address tokenAddress = 0x5d67d0efD22ab2Aa718FA34a9B63330862B6482c;
        address spenderAddress = 0xe7A38d4d4D1ebc4e441f76a70AD7CE7a5D78531C;
         
        uint256 allowanceAmount = 1_000_000 * 10**18; 

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MTXToken mtxToken = MTXToken(tokenAddress);
        
        // Get the current allowance before approval
        address owner = msg.sender;
        uint256 currentAllowance = mtxToken.allowance(owner, spenderAddress);
        console.log("Current allowance:", currentAllowance);
        
        // Approve the spender to spend tokens on behalf of the owner
        mtxToken.approve(spenderAddress, allowanceAmount);
        
        // Get the new allowance after approval
        uint256 newAllowance = mtxToken.allowance(owner, spenderAddress);
        console.log("New allowance:", newAllowance);
        console.log("Spender address:", spenderAddress);
        console.log("Owner address:", owner);
        console.log("Allowance amount approved:", allowanceAmount);

        vm.stopBroadcast();
    }
}

