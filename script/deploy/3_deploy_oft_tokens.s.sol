// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXOFT } from "../../src/oft/MTXOFT.sol";

contract DeployMTXOFT is Script {
    function run() external {
        // Replace these env vars with your own values
        address lzEndpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address accessRestriction = 0x3349D753a2f14855f876EDAA85287F3C82a4a863;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MTXOFT mtxOFT = new MTXOFT(lzEndpoint, owner, accessRestriction);
        vm.stopBroadcast();

        console.log("MTXOFT deployed to:", address(mtxOFT));
        console.log("Token name:", mtxOFT.name());
        console.log("Token symbol:", mtxOFT.symbol());
        console.log("Max supply:", mtxOFT.MAX_SUPPLY());
        console.log("Owner:", mtxOFT.owner());
    }
}
