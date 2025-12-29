// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MEXToken } from "../../src/mEXToken/MEXToken.sol";

contract DeployMTXToken is Script {
    function run() external {
        // Replace these env vars with your own values
        address lzEndpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address accessRestriction = 0xDA05A33a4F06056e24590e8B3832F1dD05a98443;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY2"));
        MEXToken mexToken = new MEXToken(lzEndpoint, owner, accessRestriction, treasury);
        vm.stopBroadcast();

        console.log("MEXToken deployed to:", address(mexToken));
        console.log("Token name:", mexToken.name());
        console.log("Token symbol:", mexToken.symbol());
        console.log("Max supply:", mexToken.MAX_SUPPLY());
        console.log("Owner:", mexToken.owner());
    }
}
