// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {MTXToken} from "../src/mTXToken/MTXToken.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";

contract MTXTokenTest is Test {
    MTXToken public token;
    AccessRestriction public accessRestriction;
    
    address public owner;
    address public treasury;
    address public manager;

    function setUp() public {
        // Set up addresses
        owner = makeAddr("owner");
        treasury = makeAddr("treasury");
        manager = makeAddr("manager");

        // Deploy AccessRestriction first
        vm.startPrank(owner);
        accessRestriction = new AccessRestriction(owner, treasury);
        
        // Grant manager role (treasury role is granted in constructor)
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        
        // Deploy MTXToken with try-catch to get error message
        MTXToken mtxToken = new MTXToken(
            address(accessRestriction),
            owner,
            address(accessRestriction)
        );

        vm.stopPrank();
    }

    function test_InitialState() public {
        // // Test token metadata
        // assertEq(token.name(), "mtx-token");
        // assertEq(token.symbol(), "MTX");
        // assertEq(token.decimals(), 18);
        // assertEq(token.totalSupply(), 0);

        // // Test ownership and access control
        // assertEq(token.owner(), owner);
        // assertTrue(accessRestriction.hasRole(0x00, owner)); // Admin role
        // assertTrue(accessRestriction.hasRole(accessRestriction.TREASURY_ROLE(), treasury));
        // assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));

        // // Test initial configuration
        // assertEq(token.maxWalletBalance(), 100_000_000 * 10**18); // 1% of max supply
        // assertEq(token.maxTransferAmount(), 5_000_000 * 10**18);  // 0.05% of max supply
        // assertEq(token.maxTxsPerWindow(), 3);
        // assertEq(token.windowSize(), 15 minutes);
        // assertEq(token.minTxInterval(), 1 minutes);
        // assertEq(token.maxTxsPerBlock(), 2);

        // // Test initial state flags
        // assertTrue(token.restrictionsEnabled());
        // assertTrue(token.checkWindowSize());
        // assertTrue(token.checkTxInterval());
        // assertTrue(token.checkBlockTxLimit());
        // assertTrue(token.checkWindowTxLimit());
        // assertTrue(token.checkBlackList());
        // assertTrue(token.checkMaxTransfer());
        // assertTrue(token.checkMaxWalletBalance());
    }
}

