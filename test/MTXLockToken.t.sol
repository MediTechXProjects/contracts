// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test,console} from "forge-std/Test.sol";
import {MTXLockToken} from "../src/lockToken/MTXLockToken.sol";
import {IMTXLockToken} from "../src/lockToken/IMTXLockToken.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MTXLockTokenTest is Test {
    MTXLockToken public lockToken;
    MockERC20 public mtxToken;
    AccessRestriction public accessRestriction;

    address public admin;
    address public manager;
    address public user1;
    address public user2;
    address public recipient;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18;

    function setUp() public {
        // Set up addresses
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        recipient = makeAddr("recipient");

        // Deploy AccessRestriction
        vm.startPrank(admin);
        AccessRestriction logic = new AccessRestriction();
        bytes memory data = abi.encodeWithSelector(
            AccessRestriction.initialize.selector,
            admin
        );
        address proxy = address(new ERC1967Proxy(address(logic), data));
        accessRestriction = AccessRestriction(proxy);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();

        // Deploy mock MTX token
        mtxToken = new MockERC20("MTX Token", "MTX");
        mtxToken.mint(address(this), INITIAL_SUPPLY);
        mtxToken.mint(admin, INITIAL_SUPPLY);
        

        // Deploy MTXLockToken
        lockToken = new MTXLockToken(address(mtxToken), address(accessRestriction));

        // Transfer tokens to lockToken contract for testing
        mtxToken.transfer(address(lockToken), INITIAL_SUPPLY);
    }

    // ============ CONSTRUCTOR TESTS ============

    function testConstructor() public view {
        assertEq(address(lockToken.mtxToken()), address(mtxToken));
        assertEq(address(lockToken.accessRestriction()), address(accessRestriction));
        assertEq(lockToken.totalLocked(), 0);
        assertEq(lockToken.totalClaimed(), 0);
    }

    function testConstructorRevertsWithZeroMTXToken() public {
        vm.expectRevert("Invalid address");
        new MTXLockToken(address(0), address(accessRestriction));
    }

    function testConstructorRevertsWithZeroAccessRestriction() public {
        vm.expectRevert("Invalid address");
        new MTXLockToken(address(mtxToken), address(0));
    }

    // ============ LOCK FUNCTION TESTS ============

    function testLock() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit IMTXLockToken.TokenLocked(user1, amount, unlockTime);
        lockToken.lock(user1, amount, unlockTime);

        assertEq(lockToken.userTotalLocked(user1), amount);
        assertEq(lockToken.totalLocked(), amount);
        (uint256 lockedAmount, uint256 lockedUnlockTime, bool lockedClaimed) = lockToken.userLockTokens(user1, 0);
        assertEq(lockedAmount, amount);
        assertEq(lockedUnlockTime, unlockTime);
        assertFalse(lockedClaimed);
    }

    function testLockMultipleTimes() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 unlockTime1 = block.timestamp + 30 days;
        uint256 unlockTime2 = block.timestamp + 60 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime1);
        lockToken.lock(user1, amount2, unlockTime2);
        vm.stopPrank();

        assertEq(lockToken.userTotalLocked(user1), amount1 + amount2);
        assertEq(lockToken.totalLocked(), amount1 + amount2);
        (uint256 lockedAmount1,,) = lockToken.userLockTokens(user1, 0);
        (uint256 lockedAmount2,,) = lockToken.userLockTokens(user1, 1);
        assertEq(lockedAmount1, amount1);
        assertEq(lockedAmount2, amount2);
    }

    function testLockMultipleUsers() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        lockToken.lock(user2, amount2, unlockTime);
        vm.stopPrank();

        assertEq(lockToken.userTotalLocked(user1), amount1);
        assertEq(lockToken.userTotalLocked(user2), amount2);
        assertEq(lockToken.totalLocked(), amount1 + amount2);
    }

    function testLockRevertsForNonAdmin() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.prank(user1);
        vm.expectRevert("Caller not admin");
        lockToken.lock(user1, amount, unlockTime);
    }

    function testLockRevertsWithZeroAmount() public {
        uint256 unlockTime = block.timestamp + 30 days;

        vm.prank(admin);
        vm.expectRevert("Invalid amount");
        lockToken.lock(user1, 0, unlockTime);
    }

    function testLockRevertsWithInvalidUnlockTime() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp; // Current time or past

        vm.prank(admin);
        vm.expectRevert("Invalid unlock time");
        lockToken.lock(user1, amount, unlockTime);
    }

    function testLockRevertsWithPastUnlockTime() public {
        
        vm.warp(block.timestamp + 7 days);

        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp - 1 days;

        vm.prank(admin);
        vm.expectRevert("Invalid unlock time");
        lockToken.lock(user1, amount, unlockTime);
    }

    // ============ CLAIM FUNCTION TESTS ============

    function testClaimSingleLock() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount, unlockTime);
        vm.stopPrank();

        // Fast forward past unlock time
        vm.warp(unlockTime + 1);

        uint256 balanceBefore = mtxToken.balanceOf(user1);

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IMTXLockToken.TokenClaimed(user1, amount, 0);
        lockToken.claim(0, 0);

        assertEq(mtxToken.balanceOf(user1), balanceBefore + amount);
        (,, bool claimed) = lockToken.userLockTokens(user1, 0);
        assertTrue(claimed);
        assertEq(lockToken.totalClaimed(), amount);
    }

    function testClaimWithRange() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 amount3 = 3000 * 10**18;

        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        lockToken.lock(user1, amount2, unlockTime);
        lockToken.lock(user1, amount3, unlockTime + 30 days);
        vm.stopPrank();

        vm.warp(unlockTime + 1);

        uint256 balanceBefore = mtxToken.balanceOf(user1);

        vm.prank(user1);
        lockToken.claim(0, 0);

        assertEq(mtxToken.balanceOf(user1), balanceBefore + amount1 + amount2);

        (,, bool claimed0) = lockToken.userLockTokens(user1, 0);
        (,, bool claimed1) = lockToken.userLockTokens(user1, 1);
        (,, bool claimed2) = lockToken.userLockTokens(user1, 2);

        assertTrue(claimed0);
        assertTrue(claimed1);
        assertFalse(claimed2);

        assertEq(lockToken.totalClaimed(), amount1 + amount2);
        assertEq(lockToken.totalLocked(), amount1 + amount2 + amount3);

        vm.warp(unlockTime + 30 days + 1);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit IMTXLockToken.TokenClaimed(user1, amount3, 2);
        lockToken.claim(0, 0);

        vm.prank(user1);
        vm.expectRevert("No tokens to claim");
        lockToken.claim(0, 0);
    }

    function testClaimAllWithZero() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        lockToken.lock(user1, amount2, unlockTime);
        vm.stopPrank();

        vm.warp(unlockTime + 1);

        uint256 balanceBefore = mtxToken.balanceOf(user1);

        vm.prank(user1);
        lockToken.claim(0, 0); // to = 0 means claim all

        assertEq(mtxToken.balanceOf(user1), balanceBefore + amount1 + amount2);
        (,, bool claimed0) = lockToken.userLockTokens(user1, 0);
        (,, bool claimed1) = lockToken.userLockTokens(user1, 1);
        assertTrue(claimed0);
        assertTrue(claimed1);
    }

    function testClaimSkipsAlreadyClaimed() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        lockToken.lock(user1, amount2, unlockTime);
        vm.stopPrank();

        vm.warp(unlockTime + 1);

        // Claim first lock
        vm.prank(user1);
        lockToken.claim(0, 1);

        uint256 balanceBefore = mtxToken.balanceOf(user1);

        // Try to claim again (should skip already claimed)
        vm.prank(user1);
        lockToken.claim(0, 0);

        // Balance should only increase by amount2
        assertEq(mtxToken.balanceOf(user1), balanceBefore + amount2);
    }

    function testClaimSkipsNotUnlocked() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 unlockTime1 = block.timestamp + 30 days;
        uint256 unlockTime2 = block.timestamp + 60 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime1);
        lockToken.lock(user1, amount2, unlockTime2);
        vm.stopPrank();

        // Fast forward past first unlock time but before second
        vm.warp(unlockTime1 + 1);

        uint256 balanceBefore = mtxToken.balanceOf(user1);

        vm.prank(user1);
        lockToken.claim(0, 0);

        // Should only claim amount1
        assertEq(mtxToken.balanceOf(user1), balanceBefore + amount1);
        (,, bool claimed0) = lockToken.userLockTokens(user1, 0);
        (,, bool claimed1) = lockToken.userLockTokens(user1, 1);
        assertTrue(claimed0);
        assertFalse(claimed1);
    }

    function testClaimRevertsWithNoTokens() public {
        vm.prank(user1);
        vm.expectRevert("No tokens to claim");
        lockToken.claim(0, 0);
    }

    function testClaimRevertsWithInvalidRange() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount, unlockTime);
        vm.stopPrank();

        vm.warp(unlockTime + 1);

        // from >= to and to != 0 should revert
        // Note: to == 0 means "claim all", so claim(1, 0) is valid
        vm.prank(user1);
        vm.expectRevert("Invalid range");
        lockToken.claim(2, 1); // from (2) >= to (1) and to != 0
    }

    function testClaimRevertsWithNoClaimableTokens() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount, unlockTime);
        vm.stopPrank();

        // Don't fast forward - tokens not unlocked yet
        vm.prank(user1);
        vm.expectRevert("No tokens to claim");
        lockToken.claim(0, 0);
    }

    function testClaimPartialRange() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 amount3 = 3000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        lockToken.lock(user1, amount2, unlockTime);
        lockToken.lock(user1, amount3, unlockTime);
        vm.stopPrank();

        vm.warp(unlockTime + 1);

        uint256 balanceBefore = mtxToken.balanceOf(user1);

        // Claim only middle lock
        vm.prank(user1);
        lockToken.claim(1, 2);

        assertEq(mtxToken.balanceOf(user1), balanceBefore + amount2);
        (,, bool claimed0) = lockToken.userLockTokens(user1, 0);
        (,, bool claimed1) = lockToken.userLockTokens(user1, 1);
        (,, bool claimed2) = lockToken.userLockTokens(user1, 2);
        assertFalse(claimed0);
        assertTrue(claimed1);
        assertFalse(claimed2);
    }

    // ============ WITHDRAW FUNCTION TESTS ============

    function testWithdraw() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;
        uint256 extraAmount = 500 * 10**18 + mtxToken.balanceOf(address(lockToken));

        // Lock some tokens
        vm.startPrank(admin);
        lockToken.lock(user1, amount, unlockTime);
        vm.stopPrank();

        vm.startPrank(admin);
        mtxToken.transfer(address(lockToken), 1500 * 10**18);
        vm.stopPrank();

        uint256 balanceBefore = mtxToken.balanceOf(recipient);

        console.log(recipient);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit IMTXLockToken.MTXTokensWithdrawn(recipient, extraAmount);
        lockToken.withdraw(recipient);

        assertEq(mtxToken.balanceOf(recipient), balanceBefore + extraAmount);
    }

    function testWithdrawRevertsForNonAdmin() public {
        vm.prank(user1);
        vm.expectRevert("Caller not admin");
        lockToken.withdraw(recipient);
    }

    function testWithdrawRevertsWithZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid address");
        lockToken.withdraw(address(0));
    }

    function testWithdrawRevertsWhenBalanceEqualsUnclaimed() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount, unlockTime);
        vm.stopPrank();

        vm.prank(admin);
        lockToken.withdraw(recipient);

        vm.prank(admin);
        vm.expectRevert("Invalid amount");
        lockToken.withdraw(recipient);
    }


    function testWithdrawAfterPartialClaim() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;
        uint256 allBalance = mtxToken.balanceOf(address(lockToken));


        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        lockToken.lock(user1, amount2, unlockTime + 30 days);
        vm.stopPrank();


        // Claim first lock
        vm.warp(unlockTime + 1);
        vm.prank(user1);
        lockToken.claim(0, 0);


        uint256 balanceBefore = mtxToken.balanceOf(recipient);
        vm.prank(admin);
        lockToken.withdraw(recipient);

        assertEq(mtxToken.balanceOf(recipient), allBalance - 3000 * 10**18);
    }

    // ============ EDGE CASE TESTS ============

    function testMultipleUsersClaimIndependently() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        lockToken.lock(user2, amount2, unlockTime);
        vm.stopPrank();

        vm.warp(unlockTime + 1);

        uint256 balance1Before = mtxToken.balanceOf(user1);
        uint256 balance2Before = mtxToken.balanceOf(user2);

        vm.prank(user1);
        lockToken.claim(0, 0);

        vm.prank(user2);
        lockToken.claim(0, 0);

        assertEq(mtxToken.balanceOf(user1), balance1Before + amount1);
        assertEq(mtxToken.balanceOf(user2), balance2Before + amount2);
        assertEq(lockToken.totalClaimed(), amount1 + amount2);
    }

    function testTotalLockedAndClaimedTracking() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 amount3 = 3000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        lockToken.lock(user1, amount2, unlockTime);
        lockToken.lock(user2, amount3, unlockTime);
        vm.stopPrank();

        assertEq(lockToken.totalLocked(), amount1 + amount2 + amount3);
        assertEq(lockToken.totalClaimed(), 0);

        vm.warp(unlockTime + 1);

        vm.prank(user1);
        lockToken.claim(0, 0);

        assertEq(lockToken.totalClaimed(), amount1 + amount2);

        vm.prank(user2);
        lockToken.claim(0, 0);

        assertEq(lockToken.totalClaimed(), amount1 + amount2 + amount3);
    }

    function testUserTotalLockedTracking() public {
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        assertEq(lockToken.userTotalLocked(user1), amount1);

        lockToken.lock(user1, amount2, unlockTime);
        assertEq(lockToken.userTotalLocked(user1), amount1 + amount2);
        vm.stopPrank();

        // userTotalLocked should not decrease after claiming
        vm.warp(unlockTime + 1);
        vm.prank(user1);
        lockToken.claim(0, 0);

        assertEq(lockToken.userTotalLocked(user1), amount1 + amount2);
    }

    function testClaimWithToGreaterThanLength() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount, unlockTime);
        vm.stopPrank();

        vm.warp(unlockTime + 1);

        // to > length should be set to length
        vm.prank(user1);
        lockToken.claim(0, 100); // to = 100, but length is 1

        (,, bool claimed) = lockToken.userLockTokens(user1, 0);
        assertTrue(claimed);
    }

    function testReentrancyProtection() public {
        uint256 amount = 1000 * 10**18;
        uint256 unlockTime = block.timestamp + 30 days;

        vm.startPrank(admin);
        lockToken.lock(user1, amount, unlockTime);
        vm.stopPrank();

        vm.warp(unlockTime + 1);

        // First claim should succeed
        vm.prank(user1);
        lockToken.claim(0, 0);

        // Second claim should fail (no tokens to claim)
        vm.prank(user1);
        vm.expectRevert("No tokens to claim");
        lockToken.claim(0, 0);
    }

    function testIntegerateTest() public {
        
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        uint256 amount3 = 3000 * 10**18;

        uint256 unlockTime = block.timestamp + 30 days;

        vm.warp(block.timestamp + 5 days);

        vm.startPrank(admin);
        lockToken.lock(user1, amount1, unlockTime);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(admin);
        lockToken.lock(user1, amount2, unlockTime);
        vm.stopPrank();

        vm.warp(block.timestamp + 13 days);

        vm.startPrank(admin);
        lockToken.lock(user1, amount3, unlockTime);
        vm.stopPrank();

        assertEq(lockToken.totalLocked(), amount1 + amount2 + amount3);

        assertEq(lockToken.totalClaimed(), 0);

        vm.warp(unlockTime + 1);

        vm.prank(user2);
        vm.expectRevert("Caller not manager");
        lockToken.claimWithManager(0 , 0 , user2);

        vm.prank(manager);
        vm.expectRevert("No tokens to claim");
        lockToken.claimWithManager(0 , 0 , user2);

        vm.prank(manager);
        lockToken.claimWithManager(0 , 0 , user1);

        assertEq(lockToken.totalClaimed(), amount1 + amount2 + amount3);

        assertEq(lockToken.totalLocked(), amount1 + amount2 + amount3);

        (uint256 amount,uint256 unlockTime2, bool claimed) = lockToken.userLockTokens(user1, 0);

        assertTrue(claimed);
        assertEq(amount , amount1);

        assertEq(mtxToken.balanceOf(user1), amount1 + amount2 + amount3);

        vm.prank(manager);
        vm.expectRevert("No tokens to claim");
        lockToken.claimWithManager(0 , 0 , user1);
    }
}

