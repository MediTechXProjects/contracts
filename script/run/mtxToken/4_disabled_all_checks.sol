// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

contract DisableAllChecks is Script {
    function run() external {
        address tokenAddress = 0x08f1725169506f690dEF8d8Db1616A2A8DD408E7;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MTXToken mtxToken = MTXToken(tokenAddress);
        
        // Disable all checks
        mtxToken.setCheckBlackList(false);
        mtxToken.setCheckMaxWalletBalance(false);
        mtxToken.setCheckMaxTransfer(false);
        mtxToken.setCheckBlockTxLimit(false);
        mtxToken.setCheckWindowTxLimit(false);

        console.log("All checks disabled for token:", tokenAddress);

        vm.stopBroadcast();
    }
}
