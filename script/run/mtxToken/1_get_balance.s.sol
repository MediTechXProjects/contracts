// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "./../../../src/mTXToken/MTXToken.sol";

contract GetUserBalance is Script {
    function run() external {

        address tokenAddress = 0x0435c5C579E9a808383563Ae50D1Db5D16c312B5;
        address userAddress = 0xe7A38d4d4D1ebc4e441f76a70AD7CE7a5D78531C;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MTXToken oapp = MTXToken(tokenAddress);

        uint256 supply = oapp.totalSupply();
        console.log("Total Supply:", supply);
        
        uint256 balance = oapp.balanceOf(userAddress);

        console.log("User balance:", balance);

        vm.stopBroadcast();
    }
}
