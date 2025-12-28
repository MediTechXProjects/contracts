// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { Airdrop } from "../../src/airdrop/Airdrop.sol";

contract DeployAirdrop is Script {
    function run() external {
        address mtxToken = 0x5d67d0efD22ab2Aa718FA34a9B63330862B6482c;
        address accessRestriction = 0xDA05A33a4F06056e24590e8B3832F1dD05a98443;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        Airdrop airdrop = new Airdrop(mtxToken, accessRestriction);
        
        vm.stopBroadcast();

        console.log("Airdrop deployed to:", address(airdrop));
        console.log("MTX Token:", address(airdrop.mtxToken()));
        console.log("Access Restriction:", address(airdrop.accessRestriction()));
    }
}

