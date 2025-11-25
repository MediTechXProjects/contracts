// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AccessRestriction } from "../../../src/accessRistriction/AccessRestriction.sol";

contract CheckRole is Script {
    function run() external {
        // Get addresses from environment variables
        address accessRestrictionAddress = 0xDA05A33a4F06056e24590e8B3832F1dD05a98443;
        address userAddress = 0xDcC7cEd9a0af57bDe46c5Fb5dcE0163c23Fc2e86;

        // Create interface instance
        AccessRestriction accessRestriction = AccessRestriction(accessRestrictionAddress);

        // Check roles
        bool isAdmin = accessRestriction.hasRole(accessRestriction.ADMIN_ROLE(), userAddress);
        bool isManager = accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), userAddress);
        bool isMTXContract = accessRestriction.hasRole(accessRestriction.MTX_CONTRACT_ROLE(), userAddress);

        // Log results
        console.log("Role check for address:", userAddress);
        console.log("Is Admin:", isAdmin);
        console.log("Is Manager:", isManager);
        console.log("Is MTX Contract:", isMTXContract);
    }
}
