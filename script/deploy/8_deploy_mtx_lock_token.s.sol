// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXLockToken } from "../../src/lockToken/MTXLockToken.sol";

contract DeployMTXLockToken is Script {
    function run() external {

        address mtxToken = 0x5d67d0efD22ab2Aa718FA34a9B63330862B6482c;
        address accessRestriction = 0xDA05A33a4F06056e24590e8B3832F1dD05a98443;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MTXLockToken lockToken = new MTXLockToken(mtxToken, accessRestriction);
        vm.stopBroadcast();

        console.log("MTXLockToken deployed to:", address(lockToken));
        console.log("MTX token:", address(lockToken.mtxToken()));
        console.log("AccessRestriction:", address(lockToken.accessRestriction()));
    }
}


