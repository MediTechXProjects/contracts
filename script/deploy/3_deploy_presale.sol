// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MTXPresale } from "../../src/presale/MTXPresale.sol";

contract DeployPresale is Script {
    function run() external {
        // Get addresses from environment variables
        address mtxToken = 0x5d67d0efD22ab2Aa718FA34a9B63330862B6482c;
        address accessRestriction = 0xDA05A33a4F06056e24590e8B3832F1dD05a98443;
        address bnbUsdPriceFeed = vm.envAddress("BNB_USD_PRICE_FEED_ADDRESS");
        
        uint256 presaleStartTime = block.timestamp + 2 hours;
        uint256 presaleEndTime = block.timestamp + 1 days + 2 hours;

        uint256 listingTime = block.timestamp + 6 hours;

        uint256 priceSixMonths = 0.025e18;
        uint256 priceThreeMonths = 0.03e18;
        uint256 priceMonthlyVesting = 0.035e18;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        MTXPresale presale = new MTXPresale(
            mtxToken,
            accessRestriction,
            bnbUsdPriceFeed,
            presaleStartTime,
            presaleEndTime,
            listingTime,
            priceSixMonths,
            priceThreeMonths,
            priceMonthlyVesting
        );
        
        vm.stopBroadcast();

        console.log("MTXPresale deployed to:", address(presale));
        console.log("MTX Token:", address(presale.mtxToken()));
        console.log("Access Restriction:", address(presale.accessRestriction()));
        console.log("BNB/USD Price Feed:", address(presale.bnbUsdPriceFeed()));
        console.log("Presale Start Time:", presale.presaleStartTime());
        console.log("Presale End Time:", presale.presaleEndTime());
        console.log("Max MTX Sold:", presale.maxMTXSold());
    }
}

