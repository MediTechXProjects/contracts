// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { IMTXPresale2 } from "../../../src/presale/IMTXPresale2.sol";

contract UpdateEndTimePresale2 is Script {
    function run() external {
        
        address presaleAddress = 0xf6aFE3B3eECf382706C3c262289997f95b4c0CA2;

        // New presale end time (unix timestamp)
        uint256 newEndTime = block.timestamp + 2 days;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IMTXPresale2 presale = IMTXPresale2(presaleAddress);

        presale.setPresaleEndTime(newEndTime);

        vm.stopBroadcast();
    }
}


