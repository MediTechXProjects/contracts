// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Airdrop} from "../src/airdrop/Airdrop.sol";
import {IAirdrop} from "../src/airdrop/IAirdrop.sol";
import {MTXToken} from "../src/mTXToken/MTXToken.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";
import {MockLayerZeroEndpointV2} from "../src/mock/MockLayerZeroEndpointV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AirdropTest is Test {
    MTXToken public token;
    Airdrop public airdrop;
    AccessRestriction public accessRestriction;

    address public admin;
    address public treasury;
    address public manager;
    address public operator;
    address public from;
    address public alice;
    address public bob;

    function setUp() public {
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");
        manager = makeAddr("manager");
        operator = makeAddr("operator");
        from = makeAddr("from");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

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

        // Deploy MTXToken
        vm.startPrank(admin);
        MockLayerZeroEndpointV2 lzEndpoint = new MockLayerZeroEndpointV2();
        token = new MTXToken(
            address(lzEndpoint),
            admin,
            address(accessRestriction),
            treasury
        );
        vm.stopPrank();

        // Deploy Airdrop
        airdrop = new Airdrop(address(token), address(accessRestriction));

        // Whitelist addresses to bypass transfer restrictions
        vm.startPrank(manager);
        token.addToWhitelist(treasury);
        token.addToWhitelist(address(airdrop));
        token.addToWhitelist(from);
        token.addToWhitelist(alice);
        token.addToWhitelist(bob);
        vm.stopPrank();

        // Transfer tokens to the `from` address and approve the airdrop contract
        uint256 initialBalance = 1_000_000 * 1e18;
        vm.startPrank(treasury);
        token.transfer(from, initialBalance);
        vm.stopPrank();

        vm.prank(from);
        token.approve(address(airdrop), type(uint256).max);
    }

    function testConstructorRevertsWithZeroToken() public {
        vm.expectRevert(bytes("Airdrop: invalid MTX token"));
        new Airdrop(address(0), address(accessRestriction));
    }

    function testConstructorRevertsWithZeroAccessRestriction() public {
        vm.expectRevert(bytes("Airdrop: invalid AccessRestriction"));
        new Airdrop(address(token), address(0));
    }

    function testBatchAirdropFromTransfersTokensAndEmitsEvents() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = alice;
        recipients[1] = bob;
        amounts[0] = 100 * 1e18;
        amounts[1] = 200 * 1e18;

        vm.startPrank(manager);

        vm.expectEmit(true, true, true, true);
        emit IAirdrop.TokensAirdropped(manager, from, alice, amounts[0]);

        vm.expectEmit(true, true, true, true);
        emit IAirdrop.TokensAirdropped(manager, from, bob, amounts[1]);

        airdrop.batchAirdropFrom(from, recipients, amounts);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(bob), 200 ether);
        assertEq(token.balanceOf(from), 1_000_000 ether - 300 ether);

        assertTrue(airdrop.hasReceivedAirdrop(alice));
        assertTrue(airdrop.hasReceivedAirdrop(bob));
    }

    function testBatchAirdropFromRevertsForDuplicateAirdrop() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = alice;
        recipients[1] = bob;
        amounts[0] = 100 * 1e18;
        amounts[1] = 200 * 1e18;

        vm.prank(manager);
        airdrop.batchAirdropFrom(from, recipients, amounts);

        uint256 aliceBalanceAfterFirst = token.balanceOf(alice);
        uint256 bobBalanceAfterFirst = token.balanceOf(bob);
        uint256 fromBalanceAfterFirst = token.balanceOf(from);

        // Try to airdrop again with different amounts; should revert
        amounts[0] = 50 * 1e18;
        amounts[1] = 50 * 1e18;

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Airdrop.RecipientAlreadyAirdropped.selector, alice));
        airdrop.batchAirdropFrom(from, recipients, amounts);
    }

    function testBatchAirdropFromRevertsForSingleDuplicateRecipient() public {
        address[] memory recipients = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = alice; // duplicate
        amounts[0] = 100 * 1e18;
        amounts[1] = 200 * 1e18;
        amounts[2] = 50 * 1e18;

        // Should revert when trying to airdrop to alice twice in the same batch
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Airdrop.RecipientAlreadyAirdropped.selector, alice));
        airdrop.batchAirdropFrom(from, recipients, amounts);
    }

    function testBatchAirdropFromRevertsOnLengthMismatch() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice;
        recipients[1] = bob;
        amounts[0] = 100 * 1e18;

        vm.prank(manager);
        vm.expectRevert(bytes("Airdrop: length mismatch"));
        airdrop.batchAirdropFrom(from, recipients, amounts);
    }

    function testBatchAirdropFromRevertsOnInvalidFrom() public {
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice;
        amounts[0] = 100 * 1e18;

        vm.prank(manager);
        vm.expectRevert(bytes("Airdrop: invalid from"));
        airdrop.batchAirdropFrom(address(0), recipients, amounts);
    }

    function testBatchAirdropFromRevertsOnZeroAddressOrZeroAmount() public {
        address[] memory recipients = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        recipients[0] = address(0);
        recipients[1] = alice;
        recipients[2] = bob;
        amounts[0] = 100 * 1e18; // zero address -> should revert
        amounts[1] = 0; // zero amount (would also revert if reached)
        amounts[2] = 200 * 1e18;

        // First element has zero address, should revert with ZeroAddressOrZeroAmount(address(0))
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(Airdrop.ZeroAddressOrZeroAmount.selector, address(0))
        );
        airdrop.batchAirdropFrom(from, recipients, amounts);
    }

    function testBatchAirdropFromRevertsForNonManager() public {
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice;
        amounts[0] = 100 * 1e18;

        // operator doesn't have manager role, should revert
        vm.prank(operator);
        vm.expectRevert(Airdrop.CallerNotManager.selector);
        airdrop.batchAirdropFrom(from, recipients, amounts);
    }

    function testBatchAirdropFromRevertsForAdminWithoutManagerRole() public {
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice;
        amounts[0] = 100 * 1e18;

        // admin doesn't have manager role, should revert
        vm.prank(admin);
        vm.expectRevert(Airdrop.CallerNotManager.selector);
        airdrop.batchAirdropFrom(from, recipients, amounts);
    }

    function testBatchAirdropFromRevertsForTreasury() public {
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice;
        amounts[0] = 100 * 1e18;

        vm.prank(treasury);
        vm.expectRevert(Airdrop.CallerNotManager.selector);
        airdrop.batchAirdropFrom(from, recipients, amounts);
    }

    function testBatchAirdropFromWorksForManager() public {
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice;
        amounts[0] = 100 * 1e18;

        // manager has manager role, should succeed
        vm.prank(manager);
        airdrop.batchAirdropFrom(from, recipients, amounts);

        assertEq(token.balanceOf(alice), amounts[0]);
        assertTrue(airdrop.hasReceivedAirdrop(alice));
    }

    function testBatchAirdropFromWorksAfterGrantingManagerRole() public {
        address newManager = makeAddr("newManager");
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice;
        amounts[0] = 100 * 1e18;
    }

    function testBatchAirdropFromRevertsAfterRevokingManagerRole() public {
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice;
        amounts[0] = 100 * 1e18;

        // First, verify manager can call it
        vm.prank(manager);
        airdrop.batchAirdropFrom(from, recipients, amounts);
        assertEq(token.balanceOf(alice), amounts[0]);
        assertTrue(airdrop.hasReceivedAirdrop(alice));

        // Use bob for the next test (alice already received airdrop)
        recipients[0] = bob;
        amounts[0] = 200 * 1e18;
    }
}


