// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";
import {IAccessRestriction} from "../src/accessRistriction/IAccessRestriction.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract AccessRestrictionTest is Test {
    AccessRestriction public accessRestriction;
    
    address public admin;
    address public treasury;
    address public manager;
    address public user;

    function setUp() public {
        // Set up addresses
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");
        manager = makeAddr("manager");
        user = makeAddr("user");

        // Deploy AccessRestriction
        vm.prank(admin);
        accessRestriction = new AccessRestriction();
        accessRestriction.initialize(admin, treasury);
    }

    function testInitialState() public view {
        // Test that admin has DEFAULT_ADMIN_ROLE
        assertTrue(accessRestriction.hasRole(accessRestriction.DEFAULT_ADMIN_ROLE(), admin));
        
        // Test that treasury has TREASURY_ROLE
        assertTrue(accessRestriction.hasRole(accessRestriction.TREASURY_ROLE(), treasury));
        
        // Test that contract is not paused initially
        assertFalse(accessRestriction.paused());
        
        // Test role constants
        assertEq(accessRestriction.ADMIN_ROLE(), keccak256("ADMIN_ROLE"));
        assertEq(accessRestriction.MANAGER_ROLE(), keccak256("MANAGER_ROLE"));
        assertEq(accessRestriction.TREASURY_ROLE(), keccak256("TREASURY_ROLE"));
    }

    // ============ ROLE MANAGEMENT TESTS ============

    function testGrantRole() public {
        // Admin can grant MANAGER_ROLE
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
    }

    function testGrantRoleFailsForNonAdmin() public {
        // Non-admin cannot grant roles
        vm.startPrank(user);
        vm.expectRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        assertFalse(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
    }

    function testRevokeRole() public {
        // First grant the role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
        
        // Then revoke it
        vm.startPrank(admin);
        accessRestriction.revokeRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        assertFalse(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
    }

    function testRevokeRoleFailsForNonAdmin() public {
        // First grant the role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Non-admin cannot revoke roles
        vm.startPrank(user);
        vm.expectRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        accessRestriction.revokeRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Role should still exist
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
    }

    function testRenounceRole() public {
        // First grant the role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
        
        // Manager can renounce their own role
        vm.startPrank(manager);
        accessRestriction.renounceRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        assertFalse(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
    }

    function testRenounceRoleFailsForDifferentAccount() public {
        // First grant the role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // User cannot renounce manager's role
        vm.startPrank(user);
        vm.expectRevert(IAccessControl.AccessControlBadConfirmation.selector);
        accessRestriction.renounceRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Role should still exist
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
    }

    // ============ PAUSE/UNPAUSE TESTS ============

    function testPauseByManager() public {
        // Grant manager role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Manager can pause
        vm.prank(manager);
        accessRestriction.pause();
        
        assertTrue(accessRestriction.paused());
    }

    function testPauseFailsForNonManager() public {
        // Non-manager cannot pause
        vm.prank(user);
        vm.expectRevert("AccessRestriction: caller is not a manager");
        accessRestriction.pause();
        
        assertFalse(accessRestriction.paused());
    }

    function testUnpauseByManager() public {
        // Grant manager role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // First pause
        vm.prank(manager);
        accessRestriction.pause();
        assertTrue(accessRestriction.paused());
        
        // Then unpause
        vm.prank(manager);
        accessRestriction.unpause();
        
        assertFalse(accessRestriction.paused());
    }

    function testUnpauseFailsForNonManager() public {
        // Grant manager role and pause
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        vm.prank(manager);
        accessRestriction.pause();
        
        // Non-manager cannot unpause
        vm.prank(user);
        vm.expectRevert("AccessRestriction: caller is not a manager");
        accessRestriction.unpause();
        
        assertTrue(accessRestriction.paused());
    }

    function testPauseUnpauseCycle() public {
        // Grant manager role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Initial state
        assertFalse(accessRestriction.paused());
        
        // Pause
        vm.prank(manager);
        accessRestriction.pause();
        assertTrue(accessRestriction.paused());
        
        // Unpause
        vm.prank(manager);
        accessRestriction.unpause();
        assertFalse(accessRestriction.paused());
        
        // Pause again
        vm.prank(manager);
        accessRestriction.pause();
        assertTrue(accessRestriction.paused());
    }

    // ============ ROLE HIERARCHY TESTS ============

    function testAdminCanGrantAllRoles() public {
        // All grants executed by admin
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.ADMIN_ROLE(), user);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), user);
        accessRestriction.grantRole(accessRestriction.TREASURY_ROLE(), user);
        vm.stopPrank();

        assertTrue(accessRestriction.hasRole(accessRestriction.ADMIN_ROLE(), user));
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), user));
        assertTrue(accessRestriction.hasRole(accessRestriction.TREASURY_ROLE(), user));
    }

    function testManagerCannotGrantRoles() public {
        // Grant manager role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Manager cannot grant roles
        vm.startPrank(manager);
        vm.expectRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), user);
        vm.stopPrank();
        
        assertFalse(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), user));
    }

    function testTreasuryCannotGrantRoles() public {
        // Treasury cannot grant roles
        vm.startPrank(treasury);
        vm.expectRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), user);
        vm.stopPrank();
        
        assertFalse(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), user));
    }

    // ============ EDGE CASE TESTS ============

    function testGrantRoleToZeroAddress() public {
        // Admin grant to zero address should not revert in OZ; assert no revert occurs
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), address(0));
        vm.stopPrank();
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), address(0)));
    }

    function testRevokeRoleFromZeroAddress() public {
        // Admin revoke from zero address should not revert in OZ
        vm.startPrank(admin);
        accessRestriction.revokeRole(accessRestriction.MANAGER_ROLE(), address(0));
        vm.stopPrank();
        // No assertion needed; just ensuring no revert
    }

    function testGrantAlreadyGrantedRole() public {
        // Grant role first time
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
        
        // Grant same role again should not fail (OpenZeppelin handles this)
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        assertTrue(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
    }

    function testRevokeNonExistentRole() public {
        // Revoke role that was never granted should not fail (OpenZeppelin handles this)
        vm.startPrank(admin);
        accessRestriction.revokeRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        assertFalse(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), manager));
    }

    function testMultipleManagersCanPause() public {
        address manager2 = makeAddr("manager2");
        
        // Grant manager role to both
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager2);
        vm.stopPrank();
        
        // Either manager can pause
        vm.prank(manager);
        accessRestriction.pause();
        assertTrue(accessRestriction.paused());
        
        // Unpause
        vm.prank(manager2);
        accessRestriction.unpause();
        assertFalse(accessRestriction.paused());
        
        // Pause again with different manager
        vm.prank(manager2);
        accessRestriction.pause();
        assertTrue(accessRestriction.paused());
    }

    function testRoleEvents() public {
        // Test that role granted event is emitted
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit IAccessControl.RoleGranted(accessRestriction.MANAGER_ROLE(), manager, admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Test that role revoked event is emitted
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit IAccessControl.RoleRevoked(accessRestriction.MANAGER_ROLE(), manager, admin);
        accessRestriction.revokeRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
    }

    function testPauseEvents() public {
        // Grant manager role
        vm.startPrank(admin);
        accessRestriction.grantRole(accessRestriction.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Test that pause event is emitted
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit Pausable.Paused(manager);
        accessRestriction.pause();
        
        // Test that unpause event is emitted
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit Pausable.Unpaused(manager);
        accessRestriction.unpause();
    }
}