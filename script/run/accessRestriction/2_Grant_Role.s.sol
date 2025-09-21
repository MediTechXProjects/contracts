

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AccessRestriction } from "../../../src/accessRistriction/AccessRestriction.sol";

contract GrantRole is Script {
    function run() external {
        // Get addresses from environment variables
        address accessRestrictionAddress = 0xB7831dF857e4d7072EeA3A3EcC72b4F2610297e4;
        address userAddress = 0xe7A38d4d4D1ebc4e441f76a70AD7CE7a5D78531C;
        
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Create interface instance
        AccessRestriction accessRestriction = AccessRestriction(accessRestrictionAddress);

        // Grant roles - uncomment the role you want to grant
        // accessRestriction.grantRole(accessRestriction.ADMIN_ROLE(), userAddress);
        // accessRestriction.grantRole(accessRestriction.TREASURY_ROLE(), userAddress);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), userAddress);
        // accessRestriction.grantRole(accessRestriction.MTX_CONTRACT_ROLE(), userAddress);

        vm.stopBroadcast();

        // Log results
        console.log("Roles granted to address:", userAddress);
    }
}
