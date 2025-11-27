

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AccessRestriction } from "../../../src/accessRistriction/AccessRestriction.sol";

contract GrantRole is Script {
    function run() external {
        // Get addresses from environment variables
        address accessRestrictionAddress = 0xDA05A33a4F06056e24590e8B3832F1dD05a98443;
        address userAddress = 0xDcC7cEd9a0af57bDe46c5Fb5dcE0163c23Fc2e86;
        
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Create interface instance
        AccessRestriction accessRestriction = AccessRestriction(accessRestrictionAddress);

        // Grant roles - uncomment the role you want to grant
        // accessRestriction.grantRole(accessRestriction.ADMIN_ROLE(), userAddress);
        // accessRestriction.grantRole(accessRestriction.MTX_CONTRACT_ROLE(), userAddress);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), userAddress);

        vm.stopBroadcast();

        // Log results
        console.log("Roles granted to address:", userAddress);
    }
}
