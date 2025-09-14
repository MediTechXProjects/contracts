// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AccessRestriction } from "../../src/accessRistriction/AccessRestriction.sol";

contract AccessRestrictionDeploy is Script {
    function run() external {
        // Replace these env vars with your own values
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        AccessRestriction accessRestriction = new AccessRestriction(admin,treasury);
        vm.stopBroadcast();

        console.log("AccessRestriction deployed to:", address(accessRestriction));
    }
}
