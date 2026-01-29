// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { MTXPresale2 } from "../../src/presale/MTXPresale2.sol";

contract DeployPresale2 is Script {
    function run() external {

        address mtxToken = 0x5d67d0efD22ab2Aa718FA34a9B63330862B6482c;
        address accessRestriction = 0xDA05A33a4F06056e24590e8B3832F1dD05a98443;
        address bnbUsdPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        
        uint256 presaleStartTime = block.timestamp;
        uint256 presaleEndTime = block.timestamp + 365 days;

        // Lock model prices (in USD with 18 decimals)
        uint256 price3Days = 0.057e18;
        uint256 price12Months = 0.044e18;
        uint256 price18Months = 0.038e18;

        uint256 lockDuration3Days = 3 days; 
        uint256 lockDuration12Months = 12 * 30 days;
        uint256 lockDuration18Months = 18 * 30 days;

        // Prepare arrays for constructor
        uint256[] memory prices = new uint256[](3);
        prices[0] = price3Days;
        prices[1] = price12Months;
        prices[2] = price18Months;

        uint256[] memory lockDurations = new uint256[](3);
        lockDurations[0] = lockDuration3Days;
        lockDurations[1] = lockDuration12Months;
        lockDurations[2] = lockDuration18Months;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        MTXPresale2 presale = new MTXPresale2(
            mtxToken,
            accessRestriction,
            bnbUsdPriceFeed,
            presaleStartTime,
            presaleEndTime,
            prices,
            lockDurations
        );
        
        vm.stopBroadcast();

        console.log("MTXPresale2 deployed to:", address(presale));
        console.log("MTX Token:", address(presale.mtxToken()));
        console.log("Access Restriction:", address(presale.accessRestriction()));
        console.log("BNB/USD Price Feed:", address(presale.bnbUsdPriceFeed()));
        console.log("Presale Start Time:", presale.presaleStartTime());
        console.log("Presale End Time:", presale.presaleEndTime());
        console.log("Max MTX Sold:", presale.maxMTXSold());
        console.log("Max Buy Per User:", presale.maxBuyPerUser());
        console.log("Next Model ID:", presale.nextModelId());
        
        // Log lock models
        console.log("\nLock Models:");
        for (uint256 i = 0; i < presale.nextModelId(); i++) {
            (uint256 price, uint256 lockDuration, bool active) = presale.lockModels(i);
            console.log("Model ID:", i);
            console.log("  Price:", price);
            console.log("  Lock Duration:", lockDuration);
            console.log("  Active:", active);
        }
    }
}

