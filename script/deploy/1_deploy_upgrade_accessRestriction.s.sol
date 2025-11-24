// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { AccessRestriction } from "../../src/accessRistriction/AccessRestriction.sol";

contract AccessRestrictionDeploy is Script {
    function run() external {
        // Replace these env vars with your own values
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        address _proxyAddress = Upgrades.deployUUPSProxy(
            "AccessRestriction.sol",
            abi.encodeCall(AccessRestriction.initialize, (admin))
        );

        address implementationAddress = Upgrades.getImplementationAddress(
            _proxyAddress
        );


        vm.stopBroadcast();

        console.log("AccessRestriction proxy address is : ", address(_proxyAddress));
        console.log("AccessRestriction implementation address is : ", address(implementationAddress));
    }
}