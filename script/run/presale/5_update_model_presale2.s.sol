// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { IMTXPresale2 } from "../../../src/presale/IMTXPresale2.sol";

contract UpdateModelPresale2 is Script {
    function run() external {
        
        address presaleAddress = 0xf6aFE3B3eECf382706C3c262289997f95b4c0CA2;

        uint256 modelId = 2;
        uint256 price = 0.035e18;
        uint256 lockDuration = 4 hours;
        bool active = true;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IMTXPresale2 presale = IMTXPresale2(presaleAddress);

        // Update lock model
        presale.updateLockModel(modelId, price, lockDuration, active);

        vm.stopBroadcast();
    }
}

