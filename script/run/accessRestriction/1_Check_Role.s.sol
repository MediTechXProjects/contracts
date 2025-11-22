// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AccessRestriction } from "../../../src/accessRistriction/AccessRestriction.sol";

contract CheckRole is Script {
    function run() external {
        // Get addresses from environment variables
        address accessRestrictionAddress = 0xe6C7a461766914f114Ecb91D77B851278A51452C;
        address userAddress = 0xe7A38d4d4D1ebc4e441f76a70AD7CE7a5D78531C;

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
