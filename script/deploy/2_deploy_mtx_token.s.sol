// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXToken } from "../../src/mTXToken/MTXToken.sol";

contract DeployMTXToken is Script {
    function run() external {
        // Replace these env vars with your own values
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address accessRestriction = vm.envAddress("ACCESS_RESTRICTION_ADDRESS");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MTXToken mtxToken = new MTXToken(lzEndpoint, owner, accessRestriction);
        vm.stopBroadcast();

        console.log("MTXToken deployed to:", address(mtxToken));
        console.log("Token name:", mtxToken.name());
        console.log("Token symbol:", mtxToken.symbol());
        console.log("Max supply:", mtxToken.MAX_SUPPLY());
        console.log("Owner:", mtxToken.owner());
    }
}
