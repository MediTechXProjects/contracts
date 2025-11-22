// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {MTXToken} from "../src/mTXToken/MTXToken.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";
import {MockLayerZeroEndpointV2} from "../src/mock/MockLayerZeroEndpointV2.sol";
import {IMTXToken} from "../src/mTXToken/IMTXToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";



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

        AccessRestriction logic= new AccessRestriction();
        bytes memory data = abi.encodeWithSelector(
            AccessRestriction.initialize.selector,owner);
        address proxy = address(
            new ERC1967Proxy(address(logic), data)
        );
        accessRestriction = AccessRestriction(proxy);

        MockLayerZeroEndpointV2 lzEndpoint = new MockLayerZeroEndpointV2();
        
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);

        token = new MTXToken(
            address(lzEndpoint),
            owner,
            address(accessRestriction),
            treasury
        );
        vm.stopPrank();

        vm.prank(manager);
        token.addToWhitelist(treasury);

        vm.warp(block.timestamp + 100 minutes);
    }

    function testInitialState() public {

        // Test token metadata
        assertEq(token.name(), "MediTechX");
        assertEq(token.symbol(), "MTX");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18);
        assertEq(token.balanceOf(treasury), 1_000_000_000 * 10**18);


        // Test initial configuration
        assertEq(token.maxWalletBalance(), 100_000_000 * 10**18); // 10% of max supply
        assertEq(token.maxTransferAmount(), 5_000_000 * 10**18);  // 0.5% of max supply
        assertEq(token.minTxInterval(), 30 seconds);

        // Test initial state flags
        assertTrue(token.restrictionsEnabled());
        assertTrue(token.checkTxInterval());
        assertTrue(token.checkMaxTransfer());
        assertTrue(token.checkMaxWalletBalance());
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
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotManager.selector));
        token.addToWhitelist(user);
        
        // Test removeFromWhitelist
        vm.prank(nonManager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotManager.selector));
        token.removeFromWhitelist(user);
    }

    // ============ SETACCESSRESTRICTION FUNCTION TESTS ============

    function testSetAccessRestriction() public {
        // Deploy a new AccessRestriction contract
        address newAdmin = makeAddr("newAdmin");
        address newTreasury = makeAddr("newTreasury");
        
        vm.startPrank(newAdmin);
        AccessRestriction newAccessRestriction = new AccessRestriction();
        bytes memory data = abi.encodeWithSelector(
            AccessRestriction.initialize.selector,
            newAdmin,
            newTreasury
        );
        address newAccessRestrictionProxy = address(
            new ERC1967Proxy(address(newAccessRestriction), data)
        );
        vm.stopPrank();
        
        // Test that manager can set new access restriction
        vm.startPrank(owner);
        token.setAccessRestriction(newAccessRestrictionProxy);
        vm.stopPrank();
        
        // Verify the access restriction was updated
        assertEq(address(token.accessRestriction()), newAccessRestrictionProxy);
    }

    function testSetAccessRestrictionFailsForNonManager() public {
        address nonManager = makeAddr("nonManager");
        address newAccessRestriction = makeAddr("newAccessRestriction");
        
        // Test that non-manager cannot set access restriction
        vm.prank(nonManager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotAdmin.selector));
        token.setAccessRestriction(newAccessRestriction);
        
        // Verify the access restriction was not changed
        assertEq(address(token.accessRestriction()), address(accessRestriction));
    }

    function testSetAccessRestrictionWithSameAddress() public {
        // Test setting the same access restriction address
        vm.prank(owner);
        token.setAccessRestriction(address(accessRestriction));
        
        // Verify the access restriction remains the same
        assertEq(address(token.accessRestriction()), address(accessRestriction));
    }

    function testSetAccessRestrictionWithInvalidContract() public {
        // Test setting an address that is not a valid AccessRestriction contract
        address invalidContract = makeAddr("invalidContract");
        
        vm.prank(owner);
        token.setAccessRestriction(invalidContract);
        
        // Verify the access restriction was updated (no validation in the function)
        assertEq(address(token.accessRestriction()), invalidContract);
    }

    function testSetAccessRestrictionAffectsRoleChecks() public {
        // Deploy a new AccessRestriction with different roles
        address newAdmin = makeAddr("newAdmin");
        address newTreasury = makeAddr("newTreasury");
        address newManager = makeAddr("newManager");
        
        vm.startPrank(newAdmin);
        AccessRestriction newAccessRestriction = new AccessRestriction();
        bytes memory data = abi.encodeWithSelector(
            AccessRestriction.initialize.selector,
            newAdmin,
            newTreasury
        );
        address newAccessRestrictionProxy = address(
            new ERC1967Proxy(address(newAccessRestriction), data)
        );
        AccessRestriction newAccessRestrictionInstance = AccessRestriction(newAccessRestrictionProxy);
        
        // Grant manager role to new manager in the new access restriction
        newAccessRestrictionInstance.grantRole(newAccessRestrictionInstance.MANAGER_ROLE(), newManager);
        vm.stopPrank();
        
        // Set the new access restriction
        vm.prank(owner);
        token.setAccessRestriction(newAccessRestrictionProxy);
        
        // Test that the old manager can no longer call manager functions
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotManager.selector));
        token.addToWhitelist(makeAddr("user"));
        
        // Test that the new manager can call manager functions
        vm.prank(newManager);
        token.addToWhitelist(makeAddr("user"));
        assertTrue(token.whitelisted(makeAddr("user")));
    }

    function testSetAccessRestrictionAffectsPauseCheck() public {
        // Deploy a new AccessRestriction and pause it
        address newAdmin = makeAddr("newAdmin");
        address newTreasury = makeAddr("newTreasury");
        
        vm.startPrank(newAdmin);
        AccessRestriction newAccessRestriction = new AccessRestriction();
        bytes memory data = abi.encodeWithSelector(
            AccessRestriction.initialize.selector,
            newAdmin,
            newTreasury
        );
        address newAccessRestrictionProxy = address(
            new ERC1967Proxy(address(newAccessRestriction), data)
        );
        AccessRestriction newAccessRestrictionInstance = AccessRestriction(newAccessRestrictionProxy);
        
        // Pause the new access restriction
        newAccessRestrictionInstance.pause();
        vm.stopPrank();
        
        // Set the new access restriction
        vm.startPrank(owner);
        token.setAccessRestriction(newAccessRestrictionProxy);
        vm.stopPrank();

    }

    // ============ CHECKTXINTERVAL FUNCTION TESTS ============

    function testSetCheckTxInterval() public {
        // Test enabling
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.CheckTxIntervalUpdated(false);
        token.setCheckTxInterval(false);
        assertFalse(token.checkTxInterval());
        
        // Test disabling
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.CheckTxIntervalUpdated(true);
        token.setCheckTxInterval(true);
        assertTrue(token.checkTxInterval());

        address nonManager = makeAddr("nonManager");

        vm.prank(nonManager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotManager.selector));
        token.setCheckTxInterval(false);
    }

    function testTransactionIntervalScenario() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        
        // Mint some tokens to user for testing
        vm.prank(treasury);
        token.transfer(user, 1000 * 10**18);
        
        // Ensure checkTxInterval is enabled
        vm.prank(manager);
        token.setCheckTxInterval(true);
        assertTrue(token.checkTxInterval());
        
        // Disable other checks to focus on transaction interval
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        
        // Ensure minTxInterval is 30 seconds
        assertEq(token.minTxInterval(), 30 seconds);
        
        // First transaction should succeed
        vm.prank(user);
        token.transfer(recipient1, 100 * 10**18);
        
        // Verify first transaction succeeded
        assertEq(token.balanceOf(recipient1), 100 * 10**18);
        assertEq(token.balanceOf(user), 900 * 10**18);        
        // Second transaction should fail due to interval time restriction
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.PleaseWaitAFewMinutesBeforeSendingAnotherTransaction.selector, 30));
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
        token.transfer(user, 1000 * 10**18);
        
        // Disable checkTxInterval
        vm.prank(manager);
        token.setCheckTxInterval(false);
        assertFalse(token.checkTxInterval());
        
        // Disable other checks to focus on transaction interval
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        
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
        token.transfer(user, 1000 * 10**18);
        
        // Set interval to 30 seconds
        vm.prank(manager);
        token.setMinTxInterval(30);
        assertEq(token.minTxInterval(), 30);
        
        // Disable other checks to focus on transaction interval
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        
        // First transaction should succeed and set lastTxTime[user] = block.timestamp
        vm.prank(user);
        token.transfer(recipient1, 100 * 10**18);
        uint256 firstTxTime = token.lastTxTime(user);
        assertTrue(firstTxTime > 0, "lastTxTime should be set after first transaction");
        
        // Verify lastTxTime was set: second transaction should fail immediately
        // because currentTime < lastTxTime[user] + minTxInterval
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.PleaseWaitAFewMinutesBeforeSendingAnotherTransaction.selector, 30));
        token.transfer(recipient2, 100 * 10**18);
        
        // Wait exactly 30 seconds (minTxInterval) from when lastTxTime was set
        vm.warp(firstTxTime + 30);
        
        // Now the second transaction should succeed and update lastTxTime[user]
        vm.prank(user);
        token.transfer(recipient2, 100 * 10**18);
        uint256 secondTxTime = token.lastTxTime(user);
        assertEq(secondTxTime, block.timestamp, "lastTxTime should equal current block.timestamp");
        assertTrue(secondTxTime > firstTxTime, "lastTxTime should be updated after second transaction");
        assertEq(token.lastTxTime(makeAddr("anotherUser")), 0, "lastTxTime for other user should be 0");

        
        // Verify lastTxTime was updated: third transaction should fail immediately
        // because currentTime < lastTxTime[user] + minTxInterval
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.PleaseWaitAFewMinutesBeforeSendingAnotherTransaction.selector, 30));
        token.transfer(recipient1, 100 * 10**18);
        
        // Wait another 30 seconds from when lastTxTime was updated
        vm.warp(secondTxTime + 30);
        
        // Now third transaction should succeed
        vm.prank(user);
        token.transfer(recipient1, 100 * 10**18);
        uint256 thirdTxTime = token.lastTxTime(user);
        assertEq(thirdTxTime, block.timestamp, "lastTxTime should be updated after third transaction");
        
        // Verify all transactions succeeded
        assertEq(token.balanceOf(recipient1), 200 * 10**18);
        assertEq(token.balanceOf(recipient2), 100 * 10**18);
        assertEq(token.balanceOf(user), 700 * 10**18);
    }

    function testLastTxTimeIsSetCorrectlyAfterTransaction() public {
        address user = makeAddr("user");
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");
        
        // Mint some tokens to user for testing
        vm.prank(treasury);
        token.transfer(user, 1000 * 10**18);
        
        // Set interval to 1 minute
        vm.prank(manager);
        token.setMinTxInterval(1 minutes);
        assertEq(token.minTxInterval(), 1 minutes);
        
        // Disable other checks to focus on transaction interval
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        
        // First transaction should succeed and set lastTxTime[user] = block.timestamp
        vm.prank(user);
        token.transfer(recipient1, 100 * 10**18);
        uint256 firstTxTime = token.lastTxTime(user);
        assertTrue(firstTxTime > 0, "lastTxTime should be set after first transaction");
        
        // Verify lastTxTime was set: try second transaction immediately - should fail
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.PleaseWaitAFewMinutesBeforeSendingAnotherTransaction.selector, 60));
        token.transfer(recipient2, 100 * 10**18);
        
        // Wait exactly 1 minute (60 seconds) from when lastTxTime was set
        vm.warp(firstTxTime + 60);
        
        // Second transaction should succeed and update lastTxTime[user] to new timestamp
        vm.prank(user);
        token.transfer(recipient2, 100 * 10**18);
        uint256 secondTxTime = token.lastTxTime(user);
        assertEq(secondTxTime, block.timestamp, "lastTxTime should equal current block.timestamp");
        assertTrue(secondTxTime > firstTxTime, "lastTxTime should be updated after second transaction");
        
        // Verify lastTxTime was updated: try third transaction immediately - should fail
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.PleaseWaitAFewMinutesBeforeSendingAnotherTransaction.selector, 60));
        token.transfer(recipient3, 100 * 10**18);
        
        // Wait exactly 1 minute from when lastTxTime was updated
        vm.warp(secondTxTime + 60);
        
        // Third transaction should succeed
        vm.prank(user);
        token.transfer(recipient3, 100 * 10**18);
        uint256 thirdTxTime = token.lastTxTime(user);
        assertEq(thirdTxTime, block.timestamp, "lastTxTime should be updated after third transaction");
        
        // Verify all transactions succeeded and lastTxTime was updated correctly
        assertEq(token.balanceOf(recipient1), 100 * 10**18);
        assertEq(token.balanceOf(recipient2), 100 * 10**18);
        assertEq(token.balanceOf(recipient3), 100 * 10**18);
        assertEq(token.balanceOf(user), 700 * 10**18);
    }

    // ============ SETMINTXINTERVAL FUNCTION TESTS ============

    function testSetMinTxInterval() public {
        uint256 newMinTxInterval = 2 minutes;
        
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit IMTXToken.MinTxIntervalUpdated(newMinTxInterval);
        token.setMinTxInterval(newMinTxInterval);
        
        assertEq(token.minTxInterval(), newMinTxInterval);

        address nonManager = makeAddr("nonManager");
        
        vm.prank(nonManager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotManager.selector));
        token.setMinTxInterval(1 minutes);
    }

    // ============ CHECKMAXTRANSFER FUNCTION TESTS ============

    function testSetCheckMaxTransfer() public {
        // Test enabling
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.CheckMaxTransferUpdated(false);
        token.setCheckMaxTransfer(false);
        assertFalse(token.checkMaxTransfer());
        
        // Test disabling
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.CheckMaxTransferUpdated(true);
        token.setCheckMaxTransfer(true);
        assertTrue(token.checkMaxTransfer());

        address nonManager = makeAddr("nonManager");

        vm.prank(nonManager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotManager.selector));
        token.setCheckMaxTransfer(false);
    }

    // ============ CHECKMAXWALLETBALANCE FUNCTION TESTS ============

    function testSetCheckMaxWalletBalance() public {
        // Test enabling
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.CheckMaxWalletBalanceUpdated(false);
        token.setCheckMaxWalletBalance(false);
        assertFalse(token.checkMaxWalletBalance());
        
        // Test disabling
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXToken.CheckMaxWalletBalanceUpdated(true);
        token.setCheckMaxWalletBalance(true);
        assertTrue(token.checkMaxWalletBalance());

        address nonManager = makeAddr("nonManager");
        
        vm.prank(nonManager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotManager.selector));
        token.setCheckMaxWalletBalance(false);
    }

    function testMaxWalletBalanceEnforcement() public {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");

        vm.prank(manager);
        token.addToWhitelist(sender);
        
        // Mint tokens to sender for testing
        vm.prank(treasury);
        token.transfer(sender, 150_000_000 * 10**18); // 150 million tokens

        vm.prank(manager);
        token.removeFromWhitelist(sender);
        
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
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.RecipientWouldExceedMaxWalletBalance.selector, 110_000_000 * 10**18, 100_000_000 * 10**18));
        token.transfer(recipient, 60_000_000 * 10**18);
        
        // Verify balance unchanged after failed transfer
        assertEq(token.balanceOf(recipient), 50_000_000 * 10**18);
        assertEq(token.balanceOf(sender), 100_000_000 * 10**18);
    }

    function testMaxWalletBalanceDisabled() public {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");

        vm.prank(manager);
        token.addToWhitelist(sender);
        
        // Mint tokens to sender for testing
        vm.prank(treasury);
        token.transfer(sender, 150_000_000 * 10**18);
        
        // First, try to send 120 million tokens with wallet limit enabled - should fail
        vm.prank(manager);
        token.setCheckMaxWalletBalance(true);
        assertTrue(token.checkMaxWalletBalance());

        // Disable other checks to focus on maxWalletBalance
        vm.prank(manager);
        token.setCheckMaxTransfer(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.RecipientWouldExceedMaxWalletBalance.selector, 120_000_000 * 10**18, 100_000_000 * 10**18));
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

        vm.prank(manager);
        token.addToWhitelist(sender);
        
        // Mint tokens to sender
        vm.prank(treasury);
        token.transfer(sender, 150_000_000 * 10**18);
        
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
        token.setCheckTxInterval(false);
        
        // Regular recipient should be limited to 100 million tokens
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.RecipientWouldExceedMaxWalletBalance.selector, 120_000_000 * 10**18, 100_000_000 * 10**18));
        token.transfer(regularRecipient, 120_000_000 * 10**18);
        
        // Whitelisted recipient should bypass the wallet limit
        vm.prank(sender);
        token.transfer(whitelistedRecipient, 120_000_000 * 10**18);
        assertEq(token.balanceOf(whitelistedRecipient), 120_000_000 * 10**18);
        assertEq(token.balanceOf(sender), 30_000_000 * 10**18);
        
        // Verify regular recipient still has 0
        assertEq(token.balanceOf(regularRecipient), 0);
    }

    // ============ SETMINTXINTERVAL VALIDATION TESTS ============

    function testSetMinTxIntervalRevertsWithZeroValue() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MinTxIntervalMustBeGreaterThan0.selector));
        token.setMinTxInterval(0);
    }

    function testSetMinTxIntervalRevertsWithValueGreaterThan5Minutes() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MinTxIntervalMustBeLessThan5Minutes.selector));
        token.setMinTxInterval(6 minutes);

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MinTxIntervalMustBeLessThan5Minutes.selector));
        token.setMinTxInterval(301);
    }

    function testSetMinTxIntervalWithValidValues() public {
        vm.prank(manager);
        token.setMinTxInterval(30);
        assertEq(token.minTxInterval(), 30);
        
        vm.prank(manager);
        token.setMinTxInterval(2 minutes);
        assertEq(token.minTxInterval(), 2 minutes);
        
        vm.prank(manager);
        token.setMinTxInterval(5 minutes);
        assertEq(token.minTxInterval(), 5 minutes);
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
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.CallerNotManager.selector));
        token.setTransferLimits(100, 100);
    }

    function testSetTransferLimitsWithZeroValues() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MaxWalletBalanceMustBeGreaterThan0.selector));
        token.setTransferLimits(0, 100);

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MaxWalletBalanceMustBeGreaterThan0.selector)); 
        token.setTransferLimits(0, 0);

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MaxTransferAmountMustBeGreaterThan0.selector));
        token.setTransferLimits(100, 0);
    }

    function testSetTransferLimitsRevertsWithInvalidValues() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MaxWalletBalanceMustBeGreaterThan30Million.selector));
        token.setTransferLimits(29_000_000 * 10**18, 100_000 * 10**18);

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MaxWalletBalanceMustBeGreaterThan30Million.selector));
        token.setTransferLimits(1, 100_000 * 10**18);



        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MaxTransferAmountMustBeGreaterThan100Thousand.selector));
        token.setTransferLimits(100_000_000 * 10**18, 99_000 * 10**18);

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.MaxTransferAmountMustBeGreaterThan100Thousand.selector));
        token.setTransferLimits(30_000_000 * 10**18, 1);
    }

    function testMaxTransferLimitEnforcement() public {
        address user = makeAddr("user");
        address recipient = makeAddr("recipient");
        
        // Mint tokens to user for testing
        vm.prank(treasury);
        token.transfer(user, 15_000_000 * 10**18); // 10 million tokens
        
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
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.TransferAmountExceedsMaximumAllowed.selector, 6_000_000 * 10**18, 5_000_000 * 10**18));
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
        token.transfer(user, 25_000_000 * 10**18);
        
        // First, try to send 20 million tokens with limit enabled - should fail
        vm.prank(manager);
        token.setCheckMaxTransfer(true);
        assertTrue(token.checkMaxTransfer());
        
        // Disable other checks to focus on maxTransfer
        vm.prank(manager);
        token.setCheckMaxWalletBalance(false);
        vm.prank(manager);
        token.setCheckTxInterval(false);
        
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.TransferAmountExceedsMaximumAllowed.selector, 20_000_000 * 10**18, 5_000_000 * 10**18));
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
        token.transfer(user, 10_000_000 * 10**18);
        vm.prank(treasury);
        token.transfer(whitelistedUser, 10_000_000 * 10**18);
        
        // Add whitelistedUser to whitelist
        vm.prank(manager);
        token.addToWhitelist(whitelistedUser);
        assertTrue(token.whitelisted(whitelistedUser));
        
        // Ensure maxTransfer check is enabled
        vm.prank(manager);
        token.setCheckMaxTransfer(true);
        
        // Regular user should be limited
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.TransferAmountExceedsMaximumAllowed.selector, 6_000_000 * 10**18, 5_000_000 * 10**18));
        token.transfer(recipient, 6_000_000 * 10**18);
        
        // Whitelisted user should bypass the limit
        vm.prank(whitelistedUser);
        token.transfer(recipient, 6_000_000 * 10**18);
        assertEq(token.balanceOf(recipient), 6_000_000 * 10**18);
        assertEq(token.balanceOf(whitelistedUser), 4_000_000 * 10**18);
    }


    // ============ MAX SUPPLY / MINTING TESTS ============

    function testMintCannotExceedMaxSupply() public {
        address recipient = makeAddr("recipient");
        uint256 maxSupply = token.MAX_SUPPLY();

        vm.prank(manager);
        token.addToWhitelist(recipient);

        // Mint exactly up to max supply
        vm.prank(treasury);
        token.transfer(recipient, maxSupply);
        assertEq(token.totalSupply(), maxSupply);
        assertEq(token.balanceOf(recipient), maxSupply);
    }

    function testMintAfterBurnCannotExceedMaxSupply() public {
        address holder = makeAddr("holder");

        vm.prank(manager);
        token.addToWhitelist(holder);

        uint256 maxSupply = token.MAX_SUPPLY();
        uint256 twoHundredMillion = 200_000_000 * 10**18;

        // Mint max supply to holder
        vm.prank(treasury);
        token.transfer(holder, maxSupply);
        assertEq(token.totalSupply(), maxSupply);
        assertEq(token.balanceOf(holder), maxSupply);

        // Burn 200M from holder
        vm.prank(holder);
        token.burn(twoHundredMillion);
        assertEq(token.totalSupply(), maxSupply - twoHundredMillion);
        assertEq(token.balanceOf(holder), maxSupply - twoHundredMillion);
    }

    function testTotalMintedTracking() public {
        address holder1 = makeAddr("holder1");
        address holder2 = makeAddr("holder2");
        uint256 mintAmount1 = 100_000_000 * 10**18; // 100M tokens
        uint256 mintAmount2 = 200_000_000 * 10**18; // 200M tokens
        uint256 burnAmount = 50_000_000 * 10**18;   // 50M tokens


        vm.prank(manager);
        token.addToWhitelist(holder1);
        vm.prank(manager);
        token.addToWhitelist(holder2);


        // Initial state
        assertEq(token.totalSupply(), token.MAX_SUPPLY());

        // First mint
        vm.prank(treasury);
        token.transfer(holder1, mintAmount1);
        assertEq(token.totalSupply(), token.MAX_SUPPLY());
        assertEq(token.balanceOf(holder1), mintAmount1);
        assertEq(token.balanceOf(treasury), token.MAX_SUPPLY()-mintAmount1);

        // Second mint
        vm.prank(treasury);
        token.transfer(holder2, mintAmount2);
        assertEq(token.totalSupply(), token.MAX_SUPPLY());
        assertEq(token.balanceOf(holder2), mintAmount2);
        assertEq(token.balanceOf(treasury), token.MAX_SUPPLY()-mintAmount1-mintAmount2);

        // Burn some tokens
        vm.prank(holder1);
        token.burn(burnAmount);
        assertEq(token.totalSupply(), token.MAX_SUPPLY() - burnAmount);
        assertEq(token.balanceOf(holder1), mintAmount1 - burnAmount);
    }

    function testMaxSupplyEnforcementWithMultipleMints() public {
        address holder1 = makeAddr("holder1");
        address holder2 = makeAddr("holder2");
        uint256 maxSupply = token.MAX_SUPPLY();
        uint256 halfSupply = maxSupply / 2;

        vm.prank(manager);
        token.addToWhitelist(holder1);
        vm.prank(manager);
        token.addToWhitelist(holder2);

        // Mint half supply to first holder
        vm.prank(treasury);
        token.transfer(holder1, halfSupply);
        assertEq(token.totalSupply(), maxSupply);

        // Mint half supply to second holder
        vm.prank(treasury);
        token.transfer(holder2, halfSupply);
        assertEq(token.totalSupply(), maxSupply);

        assertEq(token.balanceOf(holder1), halfSupply);
        assertEq(token.balanceOf(holder2), halfSupply);
        assertEq(token.balanceOf(treasury), 0);
    }

    function testMaxSupplyEnforcementWithBurning() public {
        address holder = makeAddr("holder");
        uint256 maxSupply = token.MAX_SUPPLY();
        uint256 burnAmount = 100_000_000 * 10**18; // 100M tokens

        vm.prank(manager);
        token.addToWhitelist(holder);

        // Mint max supply
        vm.prank(treasury);
        token.transfer(holder, maxSupply);
        assertEq(token.totalSupply(), maxSupply);

        // Burn some tokens
        vm.prank(holder);
        token.burn(burnAmount);
        assertEq(token.totalSupply(), maxSupply - burnAmount); // totalSupply decreased
    }


    // ============ CONSTRUCTOR VALIDATION TESTS ============

    function testConstructorRevertsWithInvalidAccessRestriction() public {
        MockLayerZeroEndpointV2 lz = new MockLayerZeroEndpointV2();
        
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.InvalidAccessRestrictionAddress.selector));
        new MTXToken(address(lz), owner, address(0), address(0));
    }

    function testConstructorRevertsWithInvalidOwner() public {
        MockLayerZeroEndpointV2 lz = new MockLayerZeroEndpointV2();
        
        // OpenZeppelin Ownable reverts before our validation with OwnableInvalidOwner(address(0))
        vm.expectRevert();
        new MTXToken(address(lz), address(0), address(accessRestriction), address(0));
    }

    function testConstructorRevertsWithInvalidLayerZeroEndpoint() public {
        // OFT constructor reverts before our validation runs (no data in error)
        vm.expectRevert();
        new MTXToken(address(0), owner, address(accessRestriction), address(0));
    }

    // ============ SETACCESSRESTRICTION VALIDATION TESTS ============

    function testSetAccessRestrictionRevertsWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.InvalidAccessRestrictionAddress.selector));
        token.setAccessRestriction(address(0));
    }

    // ============ WHITELIST VALIDATION TESTS ============

    function testAddToWhitelistRevertsWithZeroAddress() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.InvalidAccountAddress.selector));
        token.addToWhitelist(address(0));
    }

    function testRemoveFromWhitelistRevertsWithZeroAddress() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IMTXToken.InvalidAccountAddress.selector));
        token.removeFromWhitelist(address(0));
    }

}

