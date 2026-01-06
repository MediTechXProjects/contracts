// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { IMTXPresale2 } from "../../../src/presale/IMTXPresale2.sol";

contract WithdrawBnbPresale2 is Script {
    function run() external {
        
        address presaleAddress = 0xf6aFE3B3eECf382706C3c262289997f95b4c0CA2;

        address recipient = 0xB71a4183035b75b89a65380C0E8965fbf5101341;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IMTXPresale2 presale = IMTXPresale2(presaleAddress);

        // Withdraw BNB
        presale.withdrawBNB(recipient);

        vm.stopBroadcast();
    }
}

