// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {MTXToken} from "../src/mTXToken/MTXToken.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";
import {MockLayerZeroEndpointV2} from "../src/mock/MockLayerZeroEndpointV2.sol";
import {IMTXToken} from "../src/mTXToken/IMTXToken.sol";

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
        accessRestriction = new AccessRestriction();
        accessRestriction.initialize(owner, treasury);
        MockLayerZeroEndpointV2 lzEndpoint = new MockLayerZeroEndpointV2();
        
        // Grant manager role (treasury role is granted in constructor)
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        
        // Deploy MTXToken with try-catch to get error message
        token = new MTXToken(
            address(lzEndpoint),
            owner,
            address(accessRestriction)
        );

        vm.stopPrank();

        vm.warp(block.timestamp + 100 minutes);
    }

    function testInitialState() public {

        // Test token metadata
        assertEq(token.name(), "mtx-token");
        assertEq(token.symbol(), "MTX");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);


        // Test initial configuration
        assertEq(token.maxWalletBalance(), 100_000_000 * 10**18); // 1% of max supply
        assertEq(token.maxTransferAmount(), 5_000_000 * 10**18);  // 0.05% of max supply
        assertEq(token.maxTxsPerWindow(), 3);
        assertEq(token.windowSize(), 15 minutes);
        assertEq(token.minTxInterval(), 1 minutes);
        assertEq(token.maxTxsPerBlock(), 2);

        // Test initial state flags
        assertTrue(token.restrictionsEnabled());
        assertTrue(token.checkTxInterval());
        assertTrue(token.checkBlockTxLimit());
        assertTrue(token.checkWindowTxLimit());
        assertTrue(token.checkBlackList());
        assertTrue(token.checkMaxTransfer());
        assertTrue(token.checkMaxWalletBalance());
    }

    // ============ BLACKLIST FUNCTION TESTS ============

    function testAddToBlacklist() public {
        address user = makeAddr("user");
        
        // Test that manager can add to blacklist
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.Blacklisted(user, true);
        token.addToBlacklist(user);
        
        assertTrue(token.blacklisted(user));
    }

    function testRemoveFromBlacklist() public {
        address user = makeAddr("user");
        
        // First add to blacklist
        vm.prank(manager);
        token.addToBlacklist(user);
        assertTrue(token.blacklisted(user));
        
        // Then remove from blacklist
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.Blacklisted(user, false);
        token.removeFromBlacklist(user);
        
        assertFalse(token.blacklisted(user));
    }

    function testBlacklistFunctionsFailForNonManager() public {
        address nonManager = makeAddr("nonManager");
        address user = makeAddr("user");
        
        // Test addToBlacklist
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.addToBlacklist(user);
        
        // Test removeFromBlacklist
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.removeFromBlacklist(user);
    }

    // ============ WHITELIST FUNCTION TESTS ============

    function testAddToWhitelist() public {
        address user = makeAddr("user");
        
        // Test that manager can add to whitelist
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.Whitelisted(user, true);
        token.addToWhitelist(user);
        
        assertTrue(token.whitelisted(user));
    }

    function testRemoveFromWhitelist() public {
        address user = makeAddr("user");
        
        // First add to whitelist
        vm.prank(manager);
        token.addToWhitelist(user);
        assertTrue(token.whitelisted(user));
        
        // Then remove from whitelist
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.Whitelisted(user, false);
        token.removeFromWhitelist(user);
        
        assertFalse(token.whitelisted(user));
    }

    function testWhitelistFunctionsFailForNonManager() public {
        address nonManager = makeAddr("nonManager");
        address user = makeAddr("user");
        
        // Test addToWhitelist
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.addToWhitelist(user);
        
        // Test removeFromWhitelist
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.removeFromWhitelist(user);
    }

    // ============ CHECKTXINTERVAL FUNCTION TESTS ============

    function testSetCheckTxInterval() public {
        // Test enabling
        vm.prank(manager);
        token.setCheckTxInterval(false);
        assertFalse(token.checkTxInterval());
        
        // Test disabling
        vm.prank(manager);
        token.setCheckTxInterval(true);
        assertTrue(token.checkTxInterval());

        address nonManager = makeAddr("nonManager");

        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.setCheckTxInterval(false);
    }

    function testTransactionIntervalScenario() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        
        // Mint some tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 1000 * 10**18);
        
        // Ensure checkTxInterval is enabled
        vm.prank(manager);
        token.setCheckTxInterval(true);
        assertTrue(token.checkTxInterval());
        
        // Disable other checks to focus on transaction interval
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        
        // Ensure minTxInterval is 1 minute
        assertEq(token.minTxInterval(), 1 minutes);
        
        // First transaction should succeed
        vm.prank(user);
        token.transfer(recipient1, 100 * 10**18);
        
        // Verify first transaction succeeded
        assertEq(token.balanceOf(recipient1), 100 * 10**18);
        assertEq(token.balanceOf(user), 900 * 10**18);        
        // Second transaction should fail due to interval time restriction
        vm.prank(user);
        vm.expectRevert("MTXToken: must wait 1 minute between transactions");
        token.transfer(recipient2, 100 * 10**18);
        
        // Verify second transaction failed (recipient2 should have 0 balance)
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token.balanceOf(user), 900 * 10**18);
        
        // Wait 1 minute (60 seconds)
        vm.warp(block.timestamp + 60);
        
        // Now the second transaction should succeed
        vm.prank(user);
        token.transfer(recipient2, 100 * 10**18);
        
        // Verify second transaction succeeded after waiting
        assertEq(token.balanceOf(recipient2), 100 * 10**18);
        assertEq(token.balanceOf(user), 800 * 10**18);
    }

    function testTransactionIntervalDisabledScenario() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        
        // Mint some tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 1000 * 10**18);
        
        // Disable checkTxInterval
        vm.prank(manager);
        token.setCheckTxInterval(false);
        assertFalse(token.checkTxInterval());
        
        // Disable other checks to focus on transaction interval
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        
        // Both transactions should succeed immediately without waiting
        vm.prank(user);
        token.transfer(recipient1, 100 * 10**18);
        
        // Second transaction should succeed immediately
        vm.prank(user);
        token.transfer(recipient2, 100 * 10**18);
        
        // Verify both transactions succeeded
        assertEq(token.balanceOf(recipient1), 100 * 10**18);
        assertEq(token.balanceOf(recipient2), 100 * 10**18);
        assertEq(token.balanceOf(user), 800 * 10**18);
    }

    function testTransactionIntervalWithDifferentIntervals() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        
        // Mint some tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 1000 * 10**18);
        
        // Set interval to 30 seconds
        vm.prank(manager);
        token.setRateLimitingParams(3, 15 minutes, 30, 2);
        assertEq(token.minTxInterval(), 30);
        
        // Disable other checks to focus on transaction interval
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        
        // First transaction should succeed
        vm.prank(user);
        token.transfer(recipient1, 100 * 10**18);
        
        // Second transaction should fail (only 30 seconds needed, but we haven't waited)
        vm.prank(user);
        vm.expectRevert("MTXToken: must wait 1 minute between transactions");
        token.transfer(recipient2, 100 * 10**18);
        
        // Wait 30 seconds
        vm.warp(block.timestamp + 30);
        
        // Now the second transaction should succeed
        vm.prank(user);
        token.transfer(recipient2, 100 * 10**18);
        
        // Verify both transactions succeeded
        assertEq(token.balanceOf(recipient1), 100 * 10**18);
        assertEq(token.balanceOf(recipient2), 100 * 10**18);
        assertEq(token.balanceOf(user), 800 * 10**18);
    }

    // ============ CHECKBLOCKTXLIMIT FUNCTION TESTS ============

    function testSetCheckBlockTxLimit() public {
        // Test enabling
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        assertFalse(token.checkBlockTxLimit());
        
        // Test disabling
        vm.prank(manager);
        token.setCheckBlockTxLimit(true);
        assertTrue(token.checkBlockTxLimit());

        address nonManager = makeAddr("nonManager");
        
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.setCheckBlockTxLimit(false);
    }

    // ============ CHECKWINDOWTXLIMIT FUNCTION TESTS ============

    function testSetCheckWindowTxLimit() public {
        // Test enabling
        vm.prank(manager);
        token.setCheckWindowTxLimit(false);
        assertFalse(token.checkWindowTxLimit());
        
        // Test disabling
        vm.prank(manager);
        token.setCheckWindowTxLimit(true);
        assertTrue(token.checkWindowTxLimit());

        address nonManager = makeAddr("nonManager");
        
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.setCheckWindowTxLimit(false);
    }

    // ============ CHECKBLACKLIST FUNCTION TESTS ============

    function testSetCheckBlackList() public {
        // Test enabling
        vm.prank(manager);
        token.setCheckBlackList(false);
        assertFalse(token.checkBlackList());
        
        // Test disabling
        vm.prank(manager);
        token.setCheckBlackList(true);
        assertTrue(token.checkBlackList());

        address nonManager = makeAddr("nonManager");

        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.setCheckBlackList(false);
    }

    // ============ CHECKMAXTRANSFER FUNCTION TESTS ============

    function testSetCheckMaxTransfer() public {
        // Test enabling
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        assertFalse(token.checkMaxTransfer());
        
        // Test disabling
        vm.prank(manager);
        token.setCheckMaxTransfer(true);
        assertTrue(token.checkMaxTransfer());

        address nonManager = makeAddr("nonManager");

        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.setCheckMaxTransfer(false);
    }

    // ============ CHECKMAXWALLETBALANCE FUNCTION TESTS ============

    function testSetCheckMaxWalletBalance() public {
        // Test enabling
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        assertFalse(token.checkMaxWalletBalance());
        
        // Test disabling
        vm.prank(manager);
        token.setCheckMaxWalletBalance(true);
        assertTrue(token.checkMaxWalletBalance());

        address nonManager = makeAddr("nonManager");
        
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.setCheckMaxWalletBalance(false);
    }

    function testMaxWalletBalanceEnforcement() public {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        
        // Mint tokens to sender for testing
        vm.prank(treasury);
        token.mint(sender, 150_000_000 * 10**18); // 150 million tokens
        
        // Ensure maxWalletBalance check is enabled
        vm.prank(manager);
        token.setCheckMaxWalletBalance(true);
        assertTrue(token.checkMaxWalletBalance());

        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        
        // Current max wallet balance is 100 million tokens
        assertEq(token.maxWalletBalance(), 100_000_000 * 10**18);
        
        // Test transfer within wallet limit (50 million tokens) - should succeed
        vm.prank(sender);
        token.transfer(recipient, 50_000_000 * 10**18);
        assertEq(token.balanceOf(recipient), 50_000_000 * 10**18);
        assertEq(token.balanceOf(sender), 100_000_000 * 10**18);
        
        // Test transfer that would exceed recipient's wallet limit (60 million more) - should fail
        vm.prank(sender);
        vm.expectRevert("MTXToken: recipient would exceed maximum wallet balance");
        token.transfer(recipient, 60_000_000 * 10**18);
        
        // Verify balance unchanged after failed transfer
        assertEq(token.balanceOf(recipient), 50_000_000 * 10**18);
        assertEq(token.balanceOf(sender), 100_000_000 * 10**18);
    }

    function testMaxWalletBalanceDisabled() public {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        
        // Mint tokens to sender for testing
        vm.prank(treasury);
        token.mint(sender, 150_000_000 * 10**18);
        
        // First, try to send 120 million tokens with wallet limit enabled - should fail
        vm.prank(manager);
        token.setCheckMaxWalletBalance(true);
        assertTrue(token.checkMaxWalletBalance());

        // Disable other checks to focus on maxWalletBalance
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        vm.prank(manager);
        token.setCheckWindowTxLimit(false);
        
        vm.prank(sender);
        vm.expectRevert("MTXToken: recipient would exceed maximum wallet balance");
        token.transfer(recipient, 120_000_000 * 10**18);
        
        // Verify no transfer happened
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(sender), 150_000_000 * 10**18);
        
        // Now disable maxWalletBalance check
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        assertFalse(token.checkMaxWalletBalance());
        
        // Now the same 120 million transfer should succeed
        vm.prank(sender);
        token.transfer(recipient, 120_000_000 * 10**18);
        assertEq(token.balanceOf(recipient), 120_000_000 * 10**18);
        assertEq(token.balanceOf(sender), 30_000_000 * 10**18);
        
        // Test remaining tokens can also be transferred
        vm.prank(sender);
        token.transfer(recipient, 30_000_000 * 10**18);
        assertEq(token.balanceOf(recipient), 150_000_000 * 10**18);
        assertEq(token.balanceOf(sender), 0);
    }

    function testMaxWalletBalanceWithWhitelistBypass() public {
        address sender = makeAddr("sender");
        address whitelistedRecipient = makeAddr("whitelistedRecipient");
        address regularRecipient = makeAddr("regularRecipient");
        
        // Mint tokens to sender
        vm.prank(treasury);
        token.mint(sender, 150_000_000 * 10**18);
        
        // Add whitelistedRecipient to whitelist
        vm.prank(manager);
        token.addToWhitelist(whitelistedRecipient);
        assertTrue(token.whitelisted(whitelistedRecipient));
        
        // Ensure maxWalletBalance check is enabled
        vm.prank(manager);
        token.setCheckMaxWalletBalance(true);

        // Disable other checks to focus on maxWalletBalance
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        vm.prank(manager);
        token.setCheckWindowTxLimit(false);
        
        // Regular recipient should be limited to 100 million tokens
        vm.prank(sender);
        vm.expectRevert("MTXToken: recipient would exceed maximum wallet balance");
        token.transfer(regularRecipient, 120_000_000 * 10**18);
        
        // Whitelisted recipient should bypass the wallet limit
        vm.prank(sender);
        token.transfer(whitelistedRecipient, 120_000_000 * 10**18);
        assertEq(token.balanceOf(whitelistedRecipient), 120_000_000 * 10**18);
        assertEq(token.balanceOf(sender), 30_000_000 * 10**18);
        
        // Verify regular recipient still has 0
        assertEq(token.balanceOf(regularRecipient), 0);
    }

    // ============ BLOCK TRANSACTION LIMIT SCENARIO TESTS ============

    function testBlockTxLimitEnforcement() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 10_000_000 * 10**18);
        
        // Ensure blockTxLimit check is enabled
        vm.prank(manager);
        token.setCheckBlockTxLimit(true);
        assertTrue(token.checkBlockTxLimit());
        
        // Disable other checks to focus on block limit
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // Current max transactions per block is 2
        assertEq(token.maxTxsPerBlock(), 2);
        
        // First transaction in block should succeed
        vm.prank(user);
        token.transfer(recipient1, 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient1), 1_000_000 * 10**18);
        
        // Second transaction in same block should succeed
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded transactions per block limit");
        token.transfer(recipient2, 1_000_000 * 10**18);
                
        // Verify third transaction failed
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token.balanceOf(user), 9_000_000 * 10**18);
    }

    function testBlockTxLimitDisabled() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        address recipient4 = makeAddr("recipient4");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 10_000_000 * 10**18);
        
        // First, try with block limit enabled - should fail after 2 transactions
        vm.prank(manager);
        token.setCheckBlockTxLimit(true);
        assertTrue(token.checkBlockTxLimit());
        
        // Disable other checks
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // First two transactions should succeed
        vm.prank(user);
        token.transfer(recipient1, 1_000_000 * 10**18);
        
        // Third transaction should fail
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded transactions per block limit");
        token.transfer(recipient2, 1_000_000 * 10**18);
        
        // Now disable block limit check
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        assertFalse(token.checkBlockTxLimit());
        
        // Move to next block to reset the block transaction counter
        vm.roll(block.number + 1);
        
        // Now all transactions in new block should succeed
        vm.prank(user);
        token.transfer(recipient3, 1_000_000 * 10**18);
        vm.prank(user);
        token.transfer(recipient4, 1_000_000 * 10**18);
        
        // Verify all transactions succeeded
        assertEq(token.balanceOf(recipient1), 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token.balanceOf(recipient3), 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient4), 1_000_000 * 10**18);
        assertEq(token.balanceOf(user), 7_000_000 * 10**18);
    }

    function testBlockTxLimitWithWhitelistBypass() public {
        address user = makeAddr("user");
        address whitelistedUser = makeAddr("whitelistedUser");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        
        // Mint tokens to both users
        vm.prank(treasury);
        token.mint(user, 10_000_000 * 10**18);
        vm.prank(treasury);
        token.mint(whitelistedUser, 10_000_000 * 10**18);
        
        // Add whitelistedUser to whitelist
        vm.prank(manager);
        token.addToWhitelist(whitelistedUser);
        assertTrue(token.whitelisted(whitelistedUser));
        
        // Ensure blockTxLimit check is enabled
        vm.prank(manager);
        token.setCheckBlockTxLimit(true);
        
        // Disable other checks
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // Regular user should be limited to 2 transactions per block
        vm.prank(user);
        token.transfer(recipient1, 1_000_000 * 10**18);
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded transactions per block limit");
        token.transfer(recipient2, 1_000_000 * 10**18);
        
        // Whitelisted user should bypass block limit
        vm.prank(whitelistedUser);
        token.transfer(recipient1, 1_000_000 * 10**18);
        vm.prank(whitelistedUser);
        token.transfer(recipient2, 1_000_000 * 10**18);
        vm.prank(whitelistedUser);
        token.transfer(recipient3, 1_000_000 * 10**18);
        
        // Verify whitelisted user's transactions all succeeded
        assertEq(token.balanceOf(recipient1), 2_000_000 * 10**18); // 1M from user + 1M from whitelisted
        assertEq(token.balanceOf(recipient2), 1_000_000 * 10**18); // 1M from user + 1M from whitelisted
        assertEq(token.balanceOf(recipient3), 1_000_000 * 10**18); // 1M from whitelisted only
        assertEq(token.balanceOf(whitelistedUser), 7_000_000 * 10**18);
    }

    // ============ WINDOW TRANSACTION LIMIT SCENARIO TESTS ============

    function testWindowTxLimitEnforcement() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        address recipient4 = makeAddr("recipient4");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 10_000_000 * 10**18);
        
        // Ensure windowTxLimit check is enabled
        vm.prank(manager);
        token.setCheckWindowTxLimit(true);
        assertTrue(token.checkWindowTxLimit());
        
        // Disable other checks to focus on window limit
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // Current max transactions per window is 3
        assertEq(token.maxTxsPerWindow(), 3);
        assertEq(token.windowSize(), 15 minutes);
        
        // First transaction in window should succeed
        vm.prank(user);
        token.transfer(recipient1, 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient1), 1_000_000 * 10**18);
        
        // Second transaction in same window should succeed
        vm.prank(user);
        token.transfer(recipient2, 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient2), 1_000_000 * 10**18);
        
        // Third transaction in same window should succeed
        vm.prank(user);
        token.transfer(recipient3, 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient3), 1_000_000 * 10**18);
        
        // Fourth transaction in same window should fail
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded transactions per window limit");
        token.transfer(recipient4, 1_000_000 * 10**18);
        
        // Verify fourth transaction failed
        assertEq(token.balanceOf(recipient4), 0);
        assertEq(token.balanceOf(user), 7_000_000 * 10**18);
    }

    function testWindowTxLimitDisabled() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        address recipient4 = makeAddr("recipient4");
        address recipient5 = makeAddr("recipient5");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 10_000_000 * 10**18);
        
        // First, try with window limit enabled - should fail after 3 transactions
        vm.prank(manager);
        token.setCheckWindowTxLimit(true);
        assertTrue(token.checkWindowTxLimit());
        
        // Disable other checks
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // First three transactions should succeed
        vm.prank(user);
        token.transfer(recipient1, 1_000_000 * 10**18);
        vm.prank(user);
        token.transfer(recipient2, 1_000_000 * 10**18);
        vm.prank(user);
        token.transfer(recipient3, 1_000_000 * 10**18);
        
        // Fourth transaction should fail
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded transactions per window limit");
        token.transfer(recipient4, 1_000_000 * 10**18);
        
        // Now disable window limit check
        vm.prank(manager);
        token.setCheckWindowTxLimit(false);
        assertFalse(token.checkWindowTxLimit());
        
        // Now all transactions should succeed
        vm.prank(user);
        token.transfer(recipient4, 1_000_000 * 10**18);
        vm.prank(user);
        token.transfer(recipient5, 1_000_000 * 10**18);
        
        // Verify all transactions succeeded
        assertEq(token.balanceOf(recipient1), 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient2), 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient3), 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient4), 1_000_000 * 10**18);
        assertEq(token.balanceOf(recipient5), 1_000_000 * 10**18);
        assertEq(token.balanceOf(user), 5_000_000 * 10**18);
    }

    function testWindowTxLimitWithWhitelistBypass() public {
        address user = makeAddr("user");
        address whitelistedUser = makeAddr("whitelistedUser");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        address recipient4 = makeAddr("recipient4");
        
        // Mint tokens to both users
        vm.prank(treasury);
        token.mint(user, 10_000_000 * 10**18);
        vm.prank(treasury);
        token.mint(whitelistedUser, 10_000_000 * 10**18);
        
        // Add whitelistedUser to whitelist
        vm.prank(manager);
        token.addToWhitelist(whitelistedUser);
        assertTrue(token.whitelisted(whitelistedUser));
        
        // Ensure windowTxLimit check is enabled
        vm.prank(manager);
        token.setCheckWindowTxLimit(true);
        
        // Disable other checks
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // Regular user should be limited to 3 transactions per window
        vm.prank(user);
        token.transfer(recipient1, 1_000_000 * 10**18);
        vm.prank(user);
        token.transfer(recipient2, 1_000_000 * 10**18);
        vm.prank(user);
        token.transfer(recipient3, 1_000_000 * 10**18);
        
        // Fourth transaction should fail for regular user
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded transactions per window limit");
        token.transfer(recipient4, 1_000_000 * 10**18);
        
        // Whitelisted user should bypass window limit
        vm.prank(whitelistedUser);
        token.transfer(recipient1, 1_000_000 * 10**18);
        vm.prank(whitelistedUser);
        token.transfer(recipient2, 1_000_000 * 10**18);
        vm.prank(whitelistedUser);
        token.transfer(recipient3, 1_000_000 * 10**18);
        vm.prank(whitelistedUser);
        token.transfer(recipient4, 1_000_000 * 10**18);
        
        // Verify whitelisted user's transactions all succeeded
        assertEq(token.balanceOf(recipient1), 2_000_000 * 10**18); // 1M from user + 1M from whitelisted
        assertEq(token.balanceOf(recipient2), 2_000_000 * 10**18); // 1M from user + 1M from whitelisted
        assertEq(token.balanceOf(recipient3), 2_000_000 * 10**18); // 1M from user + 1M from whitelisted
        assertEq(token.balanceOf(recipient4), 1_000_000 * 10**18); // 1M from whitelisted only
        assertEq(token.balanceOf(whitelistedUser), 6_000_000 * 10**18);
    }

    // ============ WINDOW TRANSFER AMOUNT LIMIT SCENARIO TESTS ============

    function testWindowTransferAmountLimitEnforcement() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 200_000_000 * 10**18); // 200 million tokens
        
        // Ensure windowTxLimit check is enabled
        vm.prank(manager);
        token.setCheckWindowTxLimit(true);
        assertTrue(token.checkWindowTxLimit());
        
        // Disable other checks to focus on window amount limit
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // Current max amount per window is 100 million tokens
        assertEq(token.maxAmountPerWindow(), 100_000_000 * 10**18);
        assertEq(token.windowSize(), 15 minutes);
        
        // First transfer within window amount limit should succeed
        vm.prank(user);
        token.transfer(recipient1, 50_000_000 * 10**18);
        assertEq(token.balanceOf(recipient1), 50_000_000 * 10**18);
        
        // Second transfer within window amount limit should succeed
        vm.prank(user);
        token.transfer(recipient2, 30_000_000 * 10**18);
        assertEq(token.balanceOf(recipient2), 30_000_000 * 10**18);
        
        // Third transfer that would exceed window amount limit should fail
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded amount per window limit");
        token.transfer(recipient3, 30_000_000 * 10**18);
        
        // Verify third transfer failed
        assertEq(token.balanceOf(recipient3), 0);
        assertEq(token.balanceOf(user), 120_000_000 * 10**18);
    }

    function testWindowTransferAmountLimitDisabled() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 200_000_000 * 10**18);
        
        // First, try with window limit enabled - should fail when exceeding amount
        vm.prank(manager);
        token.setCheckWindowTxLimit(true);
        assertTrue(token.checkWindowTxLimit());
        
        // Disable other checks
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // First transfer should succeed
        vm.prank(user);
        token.transfer(recipient1, 50_000_000 * 10**18);
        
        // Second transfer should succeed
        vm.prank(user);
        token.transfer(recipient2, 30_000_000 * 10**18);
        
        // Third transfer should fail (exceeds 100M window limit)
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded amount per window limit");
        token.transfer(recipient3, 30_000_000 * 10**18);
        
        // Now disable window limit check
        vm.prank(manager);
        token.setCheckWindowTxLimit(false);
        assertFalse(token.checkWindowTxLimit());
        
        // Now the same transfer should succeed
        vm.prank(user);
        token.transfer(recipient3, 30_000_000 * 10**18);
        assertEq(token.balanceOf(recipient3), 30_000_000 * 10**18);
        
        // Test even larger transfer should succeed
        vm.prank(user);
        token.transfer(recipient1, 50_000_000 * 10**18);
        assertEq(token.balanceOf(recipient1), 100_000_000 * 10**18);
        assertEq(token.balanceOf(user), 40_000_000 * 10**18);
    }

    function testWindowTransferAmountLimitWithWhitelistBypass() public {
        address user = makeAddr("user");
        address whitelistedUser = makeAddr("whitelistedUser");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        
        // Mint tokens to both users
        vm.prank(treasury);
        token.mint(user, 200_000_000 * 10**18);
        vm.prank(treasury);
        token.mint(whitelistedUser, 200_000_000 * 10**18);
        
        // Add whitelistedUser to whitelist
        vm.prank(manager);
        token.addToWhitelist(whitelistedUser);
        assertTrue(token.whitelisted(whitelistedUser));
        
        // Ensure windowTxLimit check is enabled
        vm.prank(manager);
        token.setCheckWindowTxLimit(true);
        
        // Disable other checks
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // Regular user should be limited to 100M per window
        vm.prank(user);
        token.transfer(recipient1, 50_000_000 * 10**18);
        vm.prank(user);
        token.transfer(recipient2, 30_000_000 * 10**18);
        
        // Third transfer should fail for regular user (exceeds 100M window limit)
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded amount per window limit");
        token.transfer(recipient3, 30_000_000 * 10**18);
        
        // Whitelisted user should bypass window amount limit
        vm.prank(whitelistedUser);
        token.transfer(recipient1, 50_000_000 * 10**18);
        vm.prank(whitelistedUser);
        token.transfer(recipient2, 30_000_000 * 10**18);
        vm.prank(whitelistedUser);
        token.transfer(recipient3, 30_000_000 * 10**18);
        
        // Verify whitelisted user's transactions all succeeded
        assertEq(token.balanceOf(recipient1), 100_000_000 * 10**18); // 50M from user + 50M from whitelisted
        assertEq(token.balanceOf(recipient2), 60_000_000 * 10**18); // 30M from user + 30M from whitelisted
        assertEq(token.balanceOf(recipient3), 30_000_000 * 10**18); // 30M from whitelisted only
        assertEq(token.balanceOf(whitelistedUser), 90_000_000 * 10**18);
    }

    function testWindowTransferAmountLimitTimeReset() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 200_000_000 * 10**18); // 200 million tokens
        
        // Ensure windowTxLimit check is enabled
        vm.prank(manager);
        token.setCheckWindowTxLimit(true);
        assertTrue(token.checkWindowTxLimit());
        
        // Disable other checks to focus on window amount limit
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        // Current max amount per window is 100 million tokens
        assertEq(token.maxAmountPerWindow(), 100_000_000 * 10**18);
        assertEq(token.windowSize(), 15 minutes);
        
        // First transfer within window amount limit should succeed
        vm.prank(user);
        token.transfer(recipient1, 80_000_000 * 10**18);
        assertEq(token.balanceOf(recipient1), 80_000_000 * 10**18);
        
        // Second transfer within window amount limit should succeed
        vm.prank(user);
        token.transfer(recipient2, 20_000_000 * 10**18);
        assertEq(token.balanceOf(recipient2), 20_000_000 * 10**18);
        
        // Third transfer that would exceed window amount limit should fail
        vm.prank(user);
        vm.expectRevert("MTXToken: exceeded amount per window limit");
        token.transfer(recipient3, 30_000_000 * 10**18);
        
        // Verify third transfer failed
        assertEq(token.balanceOf(recipient3), 0);
        assertEq(token.balanceOf(user), 100_000_000 * 10**18);
        
        // Wait 15 minutes to reset the window
        vm.warp(block.timestamp + 16 minutes);
        
        // Move to next block to ensure window reset
        vm.roll(block.number + 1);
        
        // Now the same transfer should succeed because window has reset
        vm.prank(user);
        token.transfer(recipient3, 30_000_000 * 10**18);
        assertEq(token.balanceOf(recipient3), 30_000_000 * 10**18);
        assertEq(token.balanceOf(user), 70_000_000 * 10**18);
        
        // Test that we can now send another 70M in the new window
        vm.prank(user);
        token.transfer(recipient1, 70_000_000 * 10**18);
        assertEq(token.balanceOf(recipient1), 150_000_000 * 10**18);
        assertEq(token.balanceOf(user), 0);
    }

    // ============ SETTRANSFERLIMITS FUNCTION TESTS ============

    function testSetTransferLimits() public {
        uint256 newMaxWallet = 200_000_000 * 10**18;
        uint256 newMaxTransfer = 10_000_000 * 10**18;
        
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit IMTXToken.TransferLimitsUpdated(newMaxWallet, newMaxTransfer);
        token.setTransferLimits(newMaxWallet, newMaxTransfer);
        
        assertEq(token.maxWalletBalance(), newMaxWallet);
        assertEq(token.maxTransferAmount(), newMaxTransfer);

        address nonManager = makeAddr("nonManager");
        
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.setTransferLimits(100, 100);
    }

    function testSetTransferLimitsWithZeroValues() public {
        vm.prank(manager);
        vm.expectRevert("MTXToken: max wallet balance must be greater than 0");
        token.setTransferLimits(0, 100);

        vm.prank(manager);
        vm.expectRevert("MTXToken: max wallet balance must be greater than 0"); 
        token.setTransferLimits(0, 0);

        vm.prank(manager);
        vm.expectRevert("MTXToken: max transfer amount must be greater than 0");
        token.setTransferLimits(100, 0);
    }

    function testMaxTransferLimitEnforcement() public {
        address user = makeAddr("user");
        address recipient = makeAddr("recipient");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 15_000_000 * 10**18); // 10 million tokens
        
        // Ensure maxTransfer check is enabled
        vm.prank(manager);
        token.setCheckMaxTransfer(true);
        assertTrue(token.checkMaxTransfer());
        
        // Test transfer within limit (5 million tokens) - should succeed
        vm.prank(user);
        token.transfer(recipient, 5_000_000 * 10**18);
        assertEq(token.balanceOf(recipient), 5_000_000 * 10**18);
        assertEq(token.balanceOf(user), 10_000_000 * 10**18);
        
        // Test transfer exceeding limit (6 million tokens) - should fail
        vm.prank(user);
        vm.expectRevert("MTXToken: transfer amount exceeds maximum allowed");
        token.transfer(recipient, 6_000_000 * 10**18);
        
        // Verify balance unchanged after failed transfer
        assertEq(token.balanceOf(recipient), 5_000_000 * 10**18);
        assertEq(token.balanceOf(user), 10_000_000 * 10**18);
    }

    function testMaxTransferLimitDisabled() public {
        address user = makeAddr("user");
        address recipient = makeAddr("recipient");
        
        // Mint 25 million tokens to user for testing
        vm.prank(treasury);
        token.mint(user, 25_000_000 * 10**18);
        
        // First, try to send 20 million tokens with limit enabled - should fail
        vm.prank(manager);
        token.setCheckMaxTransfer(true);
        assertTrue(token.checkMaxTransfer());
        
        // Disable other checks to focus on maxTransfer
        vm.prank(manager);
        token.setCheckBlockTxLimit(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        vm.prank(user);
        vm.expectRevert("MTXToken: transfer amount exceeds maximum allowed");
        token.transfer(recipient, 20_000_000 * 10**18);
        
        // Verify no transfer happened
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(user), 25_000_000 * 10**18);
        
        // Now disable maxTransfer check
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        assertFalse(token.checkMaxTransfer());
        
        // Now the same 20 million transfer should succeed
        vm.prank(user);
        token.transfer(recipient, 20_000_000 * 10**18);
        assertEq(token.balanceOf(recipient), 20_000_000 * 10**18);
        assertEq(token.balanceOf(user), 5_000_000 * 10**18);
        
        // Test remaining tokens can also be transferred
        vm.prank(user);
        token.transfer(recipient, 5_000_000 * 10**18);
        assertEq(token.balanceOf(recipient), 25_000_000 * 10**18);
        assertEq(token.balanceOf(user), 0);
    }

    function testMaxTransferLimitWithWhitelistBypass() public {
        address user = makeAddr("user");
        address whitelistedUser = makeAddr("whitelistedUser");
        address recipient = makeAddr("recipient");
        
        // Mint tokens to both users
        vm.prank(treasury);
        token.mint(user, 10_000_000 * 10**18);
        vm.prank(treasury);
        token.mint(whitelistedUser, 10_000_000 * 10**18);
        
        // Add whitelistedUser to whitelist
        vm.prank(manager);
        token.addToWhitelist(whitelistedUser);
        assertTrue(token.whitelisted(whitelistedUser));
        
        // Ensure maxTransfer check is enabled
        vm.prank(manager);
        token.setCheckMaxTransfer(true);
        
        // Regular user should be limited
        vm.prank(user);
        vm.expectRevert("MTXToken: transfer amount exceeds maximum allowed");
        token.transfer(recipient, 6_000_000 * 10**18);
        
        // Whitelisted user should bypass the limit
        vm.prank(whitelistedUser);
        token.transfer(recipient, 6_000_000 * 10**18);
        assertEq(token.balanceOf(recipient), 6_000_000 * 10**18);
        assertEq(token.balanceOf(whitelistedUser), 4_000_000 * 10**18);
    }

    // ============ SETRATELIMITINGPARAMS FUNCTION TESTS ============

    function testSetRateLimitingParams() public {
        uint256 newMaxTxsPerWindow = 5;
        uint256 newWindowSize = 30 minutes;
        uint256 newMinTxInterval = 2 minutes;
        uint256 newMaxTxsPerBlock = 3;
        
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit IMTXToken.RateLimitingParamsUpdated(newMaxTxsPerWindow, newWindowSize, newMinTxInterval, newMaxTxsPerBlock);
        token.setRateLimitingParams(newMaxTxsPerWindow, newWindowSize, newMinTxInterval, newMaxTxsPerBlock);
        
        assertEq(token.maxTxsPerWindow(), newMaxTxsPerWindow);
        assertEq(token.windowSize(), newWindowSize);
        assertEq(token.minTxInterval(), newMinTxInterval);
        assertEq(token.maxTxsPerBlock(), newMaxTxsPerBlock);

        address nonManager = makeAddr("nonManager");
        
        vm.prank(nonManager);
        vm.expectRevert("MTXToken: caller is not a manager");
        token.setRateLimitingParams(1, 1, 1, 1);
    }


    function testSetRateLimitingParamsWithZeroValues() public {
        vm.prank(manager);
        token.setRateLimitingParams(0, 0, 0, 0);
        
        assertEq(token.maxTxsPerWindow(), 0);
        assertEq(token.windowSize(), 0);
        assertEq(token.minTxInterval(), 0);
        assertEq(token.maxTxsPerBlock(), 0);
    }

    // ============ MAX SUPPLY / MINTING TESTS ============

    function testMintOnlyTreasury() public {
        address recipient = makeAddr("recipient");
        address notTreasury = makeAddr("notTreasury");

        // Non-treasury cannot mint
        vm.prank(notTreasury);
        vm.expectRevert("MTXToken: caller is not treasury");
        token.mint(recipient, 1);

        // Treasury can mint
        vm.prank(treasury);
        token.mint(recipient, 1_000 * 10**18);
        assertEq(token.totalSupply(), 1_000 * 10**18);
        assertEq(token.balanceOf(recipient), 1_000 * 10**18);
    }

    function testMintCannotExceedMaxSupply() public {
        address recipient = makeAddr("recipient");
        uint256 maxSupply = token.MAX_SUPPLY();

        // Mint exactly up to max supply
        vm.prank(treasury);
        token.mint(recipient, maxSupply);
        assertEq(token.totalSupply(), maxSupply);
        assertEq(token.balanceOf(recipient), maxSupply);

        // Any additional mint should fail
        vm.prank(treasury);
        vm.expectRevert("MTXToken: minting would exceed max supply");
        token.mint(recipient, 1);
    }

    function testMintAfterBurnBelowCap() public {
        address holder = makeAddr("holder");
        uint256 maxSupply = token.MAX_SUPPLY();
        uint256 twoHundredMillion = 200_000_000 * 10**18;

        // Mint max supply to holder
        vm.prank(treasury);
        token.mint(holder, maxSupply);
        assertEq(token.totalSupply(), maxSupply);
        assertEq(token.balanceOf(holder), maxSupply);

        // Cannot mint more while at cap
        vm.prank(treasury);
        vm.expectRevert("MTXToken: minting would exceed max supply");
        token.mint(holder, 1);

        // Burn 200M from holder
        vm.prank(holder);
        token.burn(twoHundredMillion);
        assertEq(token.totalSupply(), maxSupply - twoHundredMillion);
        assertEq(token.balanceOf(holder), maxSupply - twoHundredMillion);

        // Now minting up to the freed amount should succeed
        vm.prank(treasury);
        token.mint(holder, twoHundredMillion);
        assertEq(token.totalSupply(), maxSupply);
        assertEq(token.balanceOf(holder), maxSupply);
    }

}

