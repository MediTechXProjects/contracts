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
        uint256 presaleEndTime = block.timestamp + 2 days;

        // Lock model prices (in USD with 18 decimals)
        uint256 priceSixMonths = 0.00025e18;
        uint256 priceThreeMonths = 0.0003e18;
        uint256 priceMonthlyVesting = 0.00035e18;

        // Lock durations (in seconds)
        uint256 lockDurationSixMonths = 6 hours; 
        uint256 lockDurationThreeMonths = 3 hours;
        uint256 lockDurationMonthly = 1 hours;

        // Prepare arrays for constructor
        uint256[] memory prices = new uint256[](3);
        prices[0] = priceSixMonths;
        prices[1] = priceThreeMonths;
        prices[2] = priceMonthlyVesting;

        uint256[] memory lockDurations = new uint256[](3);
        lockDurations[0] = lockDurationSixMonths;
        lockDurations[1] = lockDurationThreeMonths;
        lockDurations[2] = lockDurationMonthly;

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

