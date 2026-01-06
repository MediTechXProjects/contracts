// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { IMTXPresale2 } from "../../../src/presale/IMTXPresale2.sol";

contract BuyPresale2 is Script {
    function run() external {
        
        // Set the presale contract address
        address presaleAddress = 0xf6aFE3B3eECf382706C3c262289997f95b4c0CA2;



        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IMTXPresale2 presale = IMTXPresale2(presaleAddress);

        presale.buyExactMTX{value: 0.0001 ether}(1e18,2);

        vm.stopBroadcast();
    }
}

