// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MTXReward} from "../src/rewarding/TokenReward.sol";
import {MTXToken} from "../src/mTXToken/MTXToken.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockLayerZeroEndpointV2} from "../src/mock/MockLayerZeroEndpointV2.sol";

contract TokenRewardTest is Test {
    using ECDSA for bytes32;

    MTXReward public reward;
    MTXToken public mtxToken;
    AccessRestriction public accessRestriction;

    address public admin;
    address public rewardSigner;
    uint256 public rewardSignerPrivateKey;
    address public user1;
    address public user2;
    address public treasury;
    address public manager;

    string public constant DOMAIN_NAME = "MTXReward";
    string public constant DOMAIN_VERSION = "1";

    bytes32 public constant REWARD_TYPEHASH =
        keccak256("Reward(address user,uint256 amount,uint256 nonce)");

    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    function setUp() public {
        admin = makeAddr("admin");
        rewardSignerPrivateKey = 1;
        rewardSigner = vm.addr(rewardSignerPrivateKey);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = makeAddr("treasury");

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
        mtxToken = new MTXToken(
            address(lzEndpoint),
            admin,
            address(accessRestriction),
            treasury
        );
        vm.stopPrank();

        // Deploy MTXReward
        reward = new MTXReward(
            address(mtxToken),
            address(accessRestriction),
            rewardSigner,
            DOMAIN_NAME,
            DOMAIN_VERSION
        );

        vm.prank(manager);
        mtxToken.addToWhitelist(address(reward));
        vm.prank(manager);
        mtxToken.addToWhitelist(admin);
        vm.prank(manager);
        mtxToken.addToWhitelist(treasury);


        // Fund the reward contract with tokens
        vm.startPrank(treasury);
        mtxToken.transfer(address(reward), 1_000_000 * 10**18);
        vm.stopPrank();
    }

    // ============ HELPER FUNCTIONS ============

    function getDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(DOMAIN_NAME)),
                    keccak256(bytes(DOMAIN_VERSION)),
                    block.chainid,
                    address(reward)
                )
            );
    }

    function getStructHash(
        address user,
        uint256 amount,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(REWARD_TYPEHASH, user, amount, nonce));
    }

    function getDigest(
        address user,
        uint256 amount,
        uint256 nonce
    ) internal view returns (bytes32) {
        bytes32 structHash = getStructHash(user, amount, nonce);
        bytes32 domainSeparator = getDomainSeparator();
        return
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
    }

    function signReward(
        uint256 signerPrivateKey,
        address user,
        uint256 amount,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes32 digest = getDigest(user, amount, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // ============ CONSTRUCTOR TESTS ============

    function testConstructor() public {
        assertEq(address(reward.mtxToken()), address(mtxToken));
        assertEq(
            address(reward.accessRestriction()),
            address(accessRestriction)
        );
        assertEq(reward.rewardSigner(), rewardSigner);
        assertEq(reward.DOMAIN_SEPARATOR(), getDomainSeparator());
    }

    function testConstructorRevertsWithZeroToken() public {
        vm.expectRevert("InvalidAddress");
        new MTXReward(
            address(0),
            address(accessRestriction),
            rewardSigner,
            DOMAIN_NAME,
            DOMAIN_VERSION
        );
    }

    function testConstructorRevertsWithZeroAccessRestriction() public {
        vm.expectRevert("InvalidAddress");
        new MTXReward(
            address(mtxToken),
            address(0),
            rewardSigner,
            DOMAIN_NAME,
            DOMAIN_VERSION
        );
    }

    function testConstructorRevertsWithZeroRewardSigner() public {
        vm.expectRevert("InvalidAddress");
        new MTXReward(
            address(mtxToken),
            address(accessRestriction),
            address(0),
            DOMAIN_NAME,
            DOMAIN_VERSION
        );
    }

    // ============ SETREWARDSIGNER TESTS ============

    function testSetRewardSigner() public {
        uint256 newSignerPrivateKey = 12345;
        address newSigner = vm.addr(newSignerPrivateKey);
        vm.startPrank(admin);

        vm.expectEmit(true, true, false, true);
        emit MTXReward.RewardSignerUpdated(rewardSigner, newSigner);
        reward.setRewardSigner(newSigner);

        assertEq(reward.rewardSigner(), newSigner);
        vm.stopPrank();
    }

    function testSetRewardSignerRevertsForNonAdmin() public {
        address newSigner = makeAddr("newSigner");
        vm.prank(user1);
        vm.expectRevert("Caller not admin");
        reward.setRewardSigner(newSigner);
    }

    function testSetRewardSignerRevertsWithZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert("InvalidAddress");
        reward.setRewardSigner(address(0));
        vm.stopPrank();
    }

    // ============ WITHDRAWREMAININGTOKENS TESTS ============

    function testWithdrawRemainingTokens() public {
        address recipient = makeAddr("recipient");
        uint256 balance = mtxToken.balanceOf(address(reward));

        vm.startPrank(admin);
        reward.withdrawRemainingTokens(recipient);
        vm.stopPrank();

        assertEq(mtxToken.balanceOf(recipient), balance);
        assertEq(mtxToken.balanceOf(address(reward)), 0);
    }

    function testWithdrawRemainingTokensRevertsForNonAdmin() public {
        address recipient = makeAddr("recipient");
        vm.prank(user1);
        vm.expectRevert("Caller not admin");
        reward.withdrawRemainingTokens(recipient);
    }

    function testWithdrawRemainingTokensRevertsWithZeroBalance() public {
        // First withdraw all tokens
        address recipient1 = makeAddr("recipient1");
        vm.startPrank(admin);
        reward.withdrawRemainingTokens(recipient1);
        vm.stopPrank();

        // Try to withdraw again
        address recipient2 = makeAddr("recipient2");
        vm.startPrank(admin);
        vm.expectRevert("NothingToWithdraw");
        reward.withdrawRemainingTokens(recipient2);
        vm.stopPrank();
    }

    function testWithdrawRemainingTokensAfterPartialClaims() public {
        // Claim some rewards first
        uint256 rewardAmount = 1000 * 10**18;
        uint256 signerPrivateKey = 1;
        vm.startPrank(user1);
        bytes memory signature = signReward(
            signerPrivateKey,
            user1,
            rewardAmount,
            0
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature
        );
        vm.stopPrank();

        // Now withdraw remaining
        address recipient = makeAddr("recipient");
        uint256 remainingBalance = mtxToken.balanceOf(address(reward));

        vm.startPrank(admin);
        reward.withdrawRemainingTokens(recipient);
        vm.stopPrank();

        assertEq(mtxToken.balanceOf(recipient), remainingBalance);
    }

    // ============ CLAIMREWARD TESTS ============

    function testClaimReward() public {
        uint256 rewardAmount = 1000 * 10**18;
        uint256 nonce = 0;

        bytes memory signature = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            nonce
        );

        uint256 balanceBefore = mtxToken.balanceOf(user1);
        uint256 contractBalanceBefore = mtxToken.balanceOf(address(reward));

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit MTXReward.RewardClaimed(user1, rewardAmount, nonce);
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: nonce
            }),
            signature
        );
        vm.stopPrank();

        assertEq(
            mtxToken.balanceOf(user1),
            balanceBefore + rewardAmount
        );
        assertEq(
            mtxToken.balanceOf(address(reward)),
            contractBalanceBefore - rewardAmount
        );
        assertEq(reward.nonces(user1), 1);
    }

    function testClaimRewardMultipleTimes() public {
        uint256 rewardAmount1 = 1000 * 10**18;
        uint256 rewardAmount2 = 2000 * 10**18;
        uint256 rewardAmount3 = 1500 * 10**18;

        // First claim
        vm.startPrank(user1);
        bytes memory signature1 = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount1,
            0
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount1,
                nonce: 0
            }),
            signature1
        );
        assertEq(reward.nonces(user1), 1);

        // Second claim
        bytes memory signature2 = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount2,
            1
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount2,
                nonce: 1
            }),
            signature2
        );
        assertEq(reward.nonces(user1), 2);

        // Third claim
        bytes memory signature3 = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount3,
            2
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount3,
                nonce: 2
            }),
            signature3
        );
        vm.stopPrank();

        assertEq(reward.nonces(user1), 3);
        assertEq(
            mtxToken.balanceOf(user1),
            rewardAmount1 + rewardAmount2 + rewardAmount3
        );
    }

    function testClaimRewardRevertsWithInvalidUser() public {
        uint256 rewardAmount = 1000 * 10**18;

        bytes memory signature = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            0
        );

        // user2 tries to claim user1's reward
        vm.startPrank(user2);
        vm.expectRevert("InvalidUser");
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature
        );
        vm.stopPrank();
    }

    function testClaimRewardRevertsWithInvalidNonce() public {
        uint256 rewardAmount = 1000 * 10**18;

        // First claim with nonce 0
        vm.startPrank(user1);
        bytes memory signature1 = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            0
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature1
        );

        // Try to claim again with nonce 0 (should fail)
        vm.expectRevert("InvalidNonce");
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature1
        );

        // Try with wrong nonce (should fail)
        bytes memory signature2 = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            2
        );
        vm.expectRevert("InvalidNonce");
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 2
            }),
            signature2
        );
        vm.stopPrank();
    }

    function testClaimRewardRevertsWithZeroAmount() public {
        bytes memory signature = signReward(
            rewardSignerPrivateKey,
            user1,
            0,
            0
        );

        vm.startPrank(user1);
        vm.expectRevert("InvalidAmount");
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: 0,
                nonce: 0
            }),
            signature
        );
        vm.stopPrank();
    }

    function testClaimRewardRevertsWithInvalidSignature() public {
        uint256 rewardAmount = 1000 * 10**18;
        uint256 wrongSignerPrivateKey = 999; // Different private key

        bytes memory signature = signReward(
            wrongSignerPrivateKey,
            user1,
            rewardAmount,
            0
        );

        vm.startPrank(user1);
        vm.expectRevert("InvalidSignature");
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature
        );
        vm.stopPrank();
    }

    function testClaimRewardRevertsWithWrongSigner() public {
        uint256 rewardAmount = 1000 * 10**18;

        // Change the reward signer
        uint256 newSignerPrivateKey = 999;
        address newSigner = vm.addr(newSignerPrivateKey);
        vm.startPrank(admin);
        reward.setRewardSigner(newSigner);
        vm.stopPrank();

        // Try to claim with old signature
        bytes memory signature = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            0
        );

        vm.startPrank(user1);
        vm.expectRevert("InvalidSignature");
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature
        );
        vm.stopPrank();
    }

    function testClaimRewardWithUpdatedSigner() public {
        uint256 rewardAmount = 1000 * 10**18;
        uint256 newSignerPrivateKey = 2;

        // Update signer
        address newSigner = vm.addr(newSignerPrivateKey);
        vm.startPrank(admin);
        reward.setRewardSigner(newSigner);
        vm.stopPrank();

        // Claim with new signer
        bytes memory signature = signReward(
            newSignerPrivateKey,
            user1,
            rewardAmount,
            0
        );

        vm.startPrank(user1);
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature
        );
        vm.stopPrank();

        assertEq(mtxToken.balanceOf(user1), rewardAmount);
    }

    function testClaimRewardMultipleUsers() public {
        uint256 rewardAmount1 = 1000 * 10**18;
        uint256 rewardAmount2 = 2000 * 10**18;

        // User1 claims
        vm.startPrank(user1);
        bytes memory signature1 = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount1,
            0
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount1,
                nonce: 0
            }),
            signature1
        );
        vm.stopPrank();

        // User2 claims
        vm.startPrank(user2);
        bytes memory signature2 = signReward(
            rewardSignerPrivateKey,
            user2,
            rewardAmount2,
            0
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user2,
                amount: rewardAmount2,
                nonce: 0
            }),
            signature2
        );
        vm.stopPrank();

        assertEq(mtxToken.balanceOf(user1), rewardAmount1);
        assertEq(mtxToken.balanceOf(user2), rewardAmount2);
        assertEq(reward.nonces(user1), 1);
        assertEq(reward.nonces(user2), 1);
    }

    // ============ EDGE CASE TESTS ============

    function testNonceIncrementsCorrectly() public {
        uint256 rewardAmount = 1000 * 10**18;

        assertEq(reward.nonces(user1), 0);

        // Claim with nonce 0
        vm.startPrank(user1);
        bytes memory signature1 = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            0
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature1
        );
        assertEq(reward.nonces(user1), 1);

        // Claim with nonce 1
        bytes memory signature2 = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            1
        );
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 1
            }),
            signature2
        );
        assertEq(reward.nonces(user1), 2);
        vm.stopPrank();
    }

    function testDomainSeparatorIsImmutable() public {
        bytes32 domainSeparator1 = reward.DOMAIN_SEPARATOR();

        // Try to change signer (should not affect domain separator)
        address newSigner = makeAddr("newSigner");
        vm.startPrank(admin);
        reward.setRewardSigner(newSigner);
        vm.stopPrank();

        bytes32 domainSeparator2 = reward.DOMAIN_SEPARATOR();
        assertEq(domainSeparator1, domainSeparator2);
    }

    function testClaimRewardWithLargeAmount() public {
        uint256 rewardAmount = 1_000_000 * 10**18;

        bytes memory signature = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            0
        );

        vm.startPrank(user1);
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature
        );
        vm.stopPrank();

        assertEq(mtxToken.balanceOf(user1), rewardAmount);
    }

    function testClaimRewardWithSmallAmount() public {
        uint256 rewardAmount = 1;

        bytes memory signature = signReward(
            rewardSignerPrivateKey,
            user1,
            rewardAmount,
            0
        );

        vm.startPrank(user1);
        reward.claimReward(
            MTXReward.Reward({
                user: user1,
                amount: rewardAmount,
                nonce: 0
            }),
            signature
        );
        vm.stopPrank();

        assertEq(mtxToken.balanceOf(user1), rewardAmount);
    }
}

// ============ HELPER CONTRACTS ============

contract MockERC20FailTransfer {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return false; // Always fail
    }
}

