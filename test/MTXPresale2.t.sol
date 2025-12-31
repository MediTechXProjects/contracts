// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MTXPresale2} from "../src/presale/MTXPresale2.sol";
import {IMTXPresale2} from "../src/presale/IMTXPresale2.sol";
import {MTXToken} from "../src/mTXToken/MTXToken.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";
import {MockChainlinkPriceFeed} from "../src/mock/MockChainlinkPriceFeed.sol";
import {MockLayerZeroEndpointV2} from "../src/mock/MockLayerZeroEndpointV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MTXPresale2Test is Test {
    MTXPresale2 public presale;
    MTXToken public mtxToken;
    AccessRestriction public accessRestriction;
    MockChainlinkPriceFeed public priceFeed;

    address public admin;
    address public treasury;
    address public manager;
    address public buyer1;
    address public buyer2;
    address public buyer3;

    uint256 public constant PRICE_SIX_MONTHS = 0.05e18; // 0.05 USDT per MTX
    uint256 public constant PRICE_THREE_MONTHS = 0.06e18; // 0.06 USDT per MTX
    uint256 public constant PRICE_MONTHLY_VESTING = 0.1e18; // 0.1 USDT per MTX
    uint256 public constant BNB_PRICE_USD = 300e8; // $300 per BNB (8 decimals)
    uint256 public constant MONTH = 30 days;
    uint256 public constant SIX_MONTHS = 6 * MONTH;
    uint256 public constant THREE_MONTHS = 3 * MONTH;

    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    uint256 public modelId0;
    uint256 public modelId1;
    uint256 public modelId2;

    // Helper function to get a single purchase by index
    function getPurchase(address user, uint256 index) internal view returns (IMTXPresale2.Purchase memory) {
        (uint256 amount, uint256 unlockTime, bool claimed, uint256 model) = presale.userPurchases(user, index);
        return IMTXPresale2.Purchase({
            amount: amount,
            unlockTime: unlockTime,
            claimed: claimed,
            model: model
        });
    }

    function setUp() public {
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");
        manager = makeAddr("manager");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");

        // Set up time
        presaleStartTime = block.timestamp + 1 days;
        presaleEndTime = presaleStartTime + 30 days;

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

        // Deploy Price Feed
        priceFeed = new MockChainlinkPriceFeed(int256(BNB_PRICE_USD));

        // Prepare lock models
        uint256[] memory prices = new uint256[](3);
        prices[0] = PRICE_SIX_MONTHS;
        prices[1] = PRICE_THREE_MONTHS;
        prices[2] = PRICE_MONTHLY_VESTING;

        uint256[] memory lockDurations = new uint256[](3);
        lockDurations[0] = SIX_MONTHS;
        lockDurations[1] = THREE_MONTHS;
        lockDurations[2] = MONTH;

        // Deploy Presale
        presale = new MTXPresale2(
            address(mtxToken),
            address(accessRestriction),
            address(priceFeed),
            presaleStartTime,
            presaleEndTime,
            prices,
            lockDurations
        );

        modelId0 = 0;
        modelId1 = 1;
        modelId2 = 2;
        
        vm.prank(manager);
        mtxToken.addToWhitelist(address(presale));
        vm.prank(manager);
        mtxToken.addToWhitelist(admin);
        vm.prank(manager);
        mtxToken.addToWhitelist(treasury);

        // Transfer tokens to presale contract
        vm.startPrank(treasury);
        mtxToken.transfer(address(presale), 50_000_000 * 10**18);
        vm.stopPrank();

        // Fund buyers
        vm.deal(buyer1, 1000 ether);
        vm.deal(buyer2, 1000 ether);
        vm.deal(buyer3, 1000 ether);
    }

    // ============ CONSTRUCTOR TESTS ============

    function testConstructor() public {
        assertEq(address(presale.mtxToken()), address(mtxToken));
        assertEq(address(presale.accessRestriction()), address(accessRestriction));
        assertEq(address(presale.bnbUsdPriceFeed()), address(priceFeed));
        assertEq(presale.presaleStartTime(), presaleStartTime);
        assertEq(presale.presaleEndTime(), presaleEndTime);
        assertEq(presale.maxMTXSold(), 50_000_000e18);
        assertFalse(presale.buyDisabled());
        
        (uint256 price0, uint256 lockDuration0, bool active0) = presale.lockModels(modelId0);
        assertEq(price0, PRICE_SIX_MONTHS);
        assertEq(lockDuration0, SIX_MONTHS);
        assertTrue(active0);

        (uint256 price1, uint256 lockDuration1, bool active1) = presale.lockModels(modelId1);
        assertEq(price1, PRICE_THREE_MONTHS);
        assertEq(lockDuration1, THREE_MONTHS);
        assertTrue(active1);

        (uint256 price2, uint256 lockDuration2, bool active2) = presale.lockModels(modelId2);
        assertEq(price2, PRICE_MONTHLY_VESTING);
        assertEq(lockDuration2, MONTH);
        assertTrue(active2);
    }

    function testConstructorRevertsWithZeroAddress() public {
        uint256[] memory prices = new uint256[](1);
        prices[0] = PRICE_SIX_MONTHS;
        uint256[] memory lockDurations = new uint256[](1);
        lockDurations[0] = SIX_MONTHS;

        vm.expectRevert(IMTXPresale2.InvalidAddress.selector);
        new MTXPresale2(
            address(0),
            address(accessRestriction),
            address(priceFeed),
            presaleStartTime,
            presaleEndTime,
            prices,
            lockDurations
        );
    }

    function testConstructorRevertsWithInvalidTime() public {
        uint256[] memory prices = new uint256[](1);
        prices[0] = PRICE_SIX_MONTHS;
        uint256[] memory lockDurations = new uint256[](1);
        lockDurations[0] = SIX_MONTHS;

        vm.expectRevert(IMTXPresale2.InvalidTime.selector);
        new MTXPresale2(
            address(mtxToken),
            address(accessRestriction),
            address(priceFeed),
            presaleEndTime,
            presaleStartTime, // end before start
            prices,
            lockDurations
        );
    }

    function testConstructorRevertsWithInvalidAmount() public {
        uint256[] memory prices = new uint256[](2);
        prices[0] = PRICE_SIX_MONTHS;
        prices[1] = PRICE_THREE_MONTHS;
        uint256[] memory lockDurations = new uint256[](1);
        lockDurations[0] = SIX_MONTHS;

        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        new MTXPresale2(
            address(mtxToken),
            address(accessRestriction),
            address(priceFeed),
            presaleStartTime,
            presaleEndTime,
            prices,
            lockDurations
        );
    }

    // ============ BUYEXACTBNB TESTS ============

    function testBuyExactBNB() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        uint256 expectedUsdValue = (bnbAmount * BNB_PRICE_USD) / 1e8;
        uint256 expectedMtxAmount = (expectedUsdValue * 1e18) / PRICE_SIX_MONTHS;

        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            bnbAmount,
            expectedMtxAmount,
            modelId0
        );
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        assertEq(presale.userTotalPurchased(buyer1), 6000 * 10**18);
        assertEq(presale.totalBNBCollected(), 1 ether);
        assertEq(presale.totalMTXSold(), 6000 * 10**18);
        
        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        IMTXPresale2.Purchase memory purchase0 = getPurchase(buyer1, 0);
        assertEq(purchase0.model, modelId0);
        assertEq(purchase0.amount, 6000 * 10**18);
        assertFalse(purchase0.claimed);
    }

    function testBuyExactBNBWithDifferentModels() public {
        vm.warp(presaleStartTime + 10 days);
        uint256 bnbAmount = 1 ether;

        // Buy with modelId0
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            modelId0
        );
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        vm.warp(presaleStartTime + 21 days);

        // Buy with modelId1
        vm.prank(buyer2);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer2,
            1 ether,
            5000 * 10**18,
            modelId1
        );
        presale.buyExactBNB{value: bnbAmount}(modelId1);

        // Buy with modelId2
        vm.prank(buyer3);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer3,
            1 ether,
            3000 * 10**18,
            modelId2
        );
        presale.buyExactBNB{value: bnbAmount}(modelId2);

        assertEq(presale.totalBNBCollected(), 3 ether);
        assertEq(presale.totalMTXSold(), 14000 * 10**18);
        assertEq(address(presale).balance, 3 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);
        assertEq(mtxToken.balanceOf(buyer2), 0);
        assertEq(mtxToken.balanceOf(buyer3), 0);

        IMTXPresale2.Purchase memory purchase1_0 = getPurchase(buyer1, 0);
        assertEq(purchase1_0.model, modelId0);
        assertEq(purchase1_0.amount, 6000 * 10**18);
        assertFalse(purchase1_0.claimed);

        IMTXPresale2.Purchase memory purchase2_0 = getPurchase(buyer2, 0);
        assertEq(purchase2_0.model, modelId1);
        assertEq(purchase2_0.amount, 5000 * 10**18);
        assertFalse(purchase2_0.claimed);

        IMTXPresale2.Purchase memory purchase3_0 = getPurchase(buyer3, 0);
        assertEq(purchase3_0.model, modelId2);
        assertEq(purchase3_0.amount, 3000 * 10**18);
        assertFalse(purchase3_0.claimed);
    }

    function testBuyExactBNBOneUserDifferentModels() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        
        // One user buys with modelId0
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            modelId0
        );
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        // Same user buys with modelId1
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            1 ether,
            5000 * 10**18,
            modelId1
        );
        presale.buyExactBNB{value: bnbAmount}(modelId1);

        // Same user buys with modelId2
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            1 ether,
            3000 * 10**18,
            modelId2
        );
        presale.buyExactBNB{value: bnbAmount}(modelId2);

        // Verify totals
        assertEq(presale.userTotalPurchased(buyer1), 14000 * 10**18); // 6000 + 5000 + 3000
        assertEq(presale.totalBNBCollected(), 3 ether);
        assertEq(presale.totalMTXSold(), 14000 * 10**18);
        assertEq(address(presale).balance, 3 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        // Verify user has 3 separate purchases (one for each model)
        IMTXPresale2.Purchase memory purchase0 = getPurchase(buyer1, 0);
        assertEq(purchase0.model, modelId0);
        assertEq(purchase0.amount, 6000 * 10**18);
        assertFalse(purchase0.claimed);
        
        // Check second purchase (modelId1)
        IMTXPresale2.Purchase memory purchase1 = getPurchase(buyer1, 1);
        assertEq(purchase1.model, modelId1);
        assertEq(purchase1.amount, 5000 * 10**18);
        assertFalse(purchase1.claimed);
        
        // Check third purchase (modelId2)
        IMTXPresale2.Purchase memory purchase2 = getPurchase(buyer1, 2);
        assertEq(purchase2.model, modelId2);
        assertEq(purchase2.amount, 3000 * 10**18);
        assertFalse(purchase2.claimed);
    }

    function testBuyExactBNBSameModelThreeTimes() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        
        // User buys modelId0 first time
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            modelId0
        );
        presale.buyExactBNB{value: bnbAmount}(modelId0);
        
        uint256 firstPurchase = presale.userTotalPurchased(buyer1);
        assertEq(firstPurchase, 6000 * 10**18);

        // Same user buys modelId0 second time
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            modelId0
        );
        presale.buyExactBNB{value: bnbAmount}(modelId0);
        
        uint256 secondPurchase = presale.userTotalPurchased(buyer1);
        assertEq(secondPurchase, 12000 * 10**18); // 6000 + 6000

        // Same user buys modelId0 third time
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            modelId0
        );
        presale.buyExactBNB{value: bnbAmount}(modelId0);
        
        uint256 thirdPurchase = presale.userTotalPurchased(buyer1);
        assertEq(thirdPurchase, 18000 * 10**18); // 6000 + 6000 + 6000

        // Verify totals
        assertEq(presale.totalBNBCollected(), 3 ether);
        assertEq(presale.totalMTXSold(), 18000 * 10**18);
        assertEq(address(presale).balance, 3 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        // Verify user has 3 separate purchase entries
        IMTXPresale2.Purchase memory purchase0 = getPurchase(buyer1, 0);
        assertEq(purchase0.model, modelId0);
        assertEq(purchase0.amount, 6000 * 10**18);
        IMTXPresale2.Purchase memory purchase1 = getPurchase(buyer1, 1);
        assertEq(purchase1.model, modelId0);
        assertEq(purchase1.amount, 6000 * 10**18);
        IMTXPresale2.Purchase memory purchase2 = getPurchase(buyer1, 2);
        assertEq(purchase2.model, modelId0);
        assertEq(purchase2.amount, 6000 * 10**18);
    }

    function testBuyExactBNBRevertsBeforePresaleStart() public {
        vm.warp(presaleStartTime - 1);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.PresaleNotActive.selector);
        presale.buyExactBNB{value: 1 ether}(modelId0);
    }

    function testBuyExactBNBRevertsAfterPresaleEnd() public {
        vm.warp(presaleEndTime);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.PresaleNotActive.selector);
        presale.buyExactBNB{value: 1 ether}(modelId0);
    }

    function testBuyExactBNBRevertsWithZeroValue() public {
        vm.warp(presaleStartTime + 1 days);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.buyExactBNB{value: 0}(modelId0);
    }

    function testBuyExactBNBRevertsWhenSaleLimitExceeded() public {
        vm.warp(presaleStartTime + 1 days);
        // Set a very low sale limit
        vm.prank(manager);
        presale.setSaleLimit(1 ether);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.SaleLimitExceeded.selector);
        presale.buyExactBNB{value: 5 ether}(modelId0);
    }

    // ============ BUYEXACTMTX TESTS ============

    function testBuyExactMTX() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 mtxWanted = 1000 * 10**18;
        uint256 usdRequired = (mtxWanted * PRICE_THREE_MONTHS) / 1e18;
        uint256 bnbRequired = (usdRequired * 1e8) / BNB_PRICE_USD;

        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            bnbRequired,
            mtxWanted,
            modelId1
        );
        presale.buyExactMTX{value: 1 ether}(mtxWanted, modelId1);

        assertEq(presale.userTotalPurchased(buyer1), mtxWanted);
        assertEq(presale.totalBNBCollected(), bnbRequired);
        assertEq(presale.totalMTXSold(), mtxWanted);
        assertEq(address(presale).balance, bnbRequired);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        assertEq(buyer1.balance, 1000 ether - bnbRequired);

        IMTXPresale2.Purchase memory purchase0 = getPurchase(buyer1, 0);
        assertEq(purchase0.model, modelId1);
        assertEq(purchase0.amount, mtxWanted);
        assertFalse(purchase0.claimed);
    }

    function testBuyExactMTXWithRefund() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 mtxWanted = 1000 * 10**18;
        uint256 usdRequired = (mtxWanted * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbRequired = (usdRequired * 1e8) / BNB_PRICE_USD;
        uint256 bnbSent = bnbRequired + 0.5 ether;
        uint256 expectedRefund = bnbSent - bnbRequired;

        uint256 balanceBefore = buyer1.balance;

        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbSent}(mtxWanted, modelId0);

        uint256 balanceAfter = buyer1.balance;
        assertEq(balanceBefore - balanceAfter, bnbRequired); // Only required amount deducted
    }

    function testBuyExactMTXOneUserDifferentModels() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Calculate BNB required for each model with same MTX amount
        uint256 mtxWanted = 1000 * 10**18;
        
        // Buy with modelId0
        uint256 usdRequired1 = (mtxWanted * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbRequired1 = (usdRequired1 * 1e8) / BNB_PRICE_USD;
        
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            bnbRequired1,
            mtxWanted,
            modelId0
        );
        presale.buyExactMTX{value: 1 ether}(mtxWanted, modelId0);
        
        uint256 firstPurchase = presale.userTotalPurchased(buyer1);
        assertEq(firstPurchase, mtxWanted);

        // Buy with modelId1
        uint256 usdRequired2 = (mtxWanted * PRICE_THREE_MONTHS) / 1e18;
        uint256 bnbRequired2 = (usdRequired2 * 1e8) / BNB_PRICE_USD;
        
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            bnbRequired2,
            mtxWanted,
            modelId1
        );
        presale.buyExactMTX{value: 1 ether}(mtxWanted, modelId1);
        
        uint256 secondPurchase = presale.userTotalPurchased(buyer1);
        assertEq(secondPurchase, mtxWanted * 2); // 1000 + 1000

        // Buy with modelId2
        uint256 usdRequired3 = (mtxWanted * PRICE_MONTHLY_VESTING) / 1e18;
        uint256 bnbRequired3 = (usdRequired3 * 1e8) / BNB_PRICE_USD;
        
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale2.TokensPurchased(
            buyer1,
            bnbRequired3,
            mtxWanted,
            modelId2
        );
        presale.buyExactMTX{value: 1 ether}(mtxWanted, modelId2);
        
        uint256 thirdPurchase = presale.userTotalPurchased(buyer1);
        assertEq(thirdPurchase, mtxWanted * 3); // 1000 + 1000 + 1000

        // Verify totals
        uint256 totalBnbCollected = bnbRequired1 + bnbRequired2 + bnbRequired3;
        assertEq(presale.userTotalPurchased(buyer1), 3000 * 10**18); // 1000 + 1000 + 1000
        assertEq(presale.totalBNBCollected(), totalBnbCollected);
        assertEq(presale.totalMTXSold(), 3000 * 10**18);
        assertEq(address(presale).balance, totalBnbCollected);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        // Verify user has 3 separate purchases (one for each model)
        IMTXPresale2.Purchase memory purchase0 = getPurchase(buyer1, 0);
        assertEq(purchase0.model, modelId0);
        assertEq(purchase0.amount, mtxWanted);
        assertFalse(purchase0.claimed);
        
        // Check second purchase (modelId1)
        IMTXPresale2.Purchase memory purchase1 = getPurchase(buyer1, 1);
        assertEq(purchase1.model, modelId1);
        assertEq(purchase1.amount, mtxWanted);
        assertFalse(purchase1.claimed);
        
        // Check third purchase (modelId2)
        IMTXPresale2.Purchase memory purchase2 = getPurchase(buyer1, 2);
        assertEq(purchase2.model, modelId2);
        assertEq(purchase2.amount, mtxWanted);
        assertFalse(purchase2.claimed);
    }

    function testBuyExactMTXRevertsWithInsufficientBNB() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 mtxWanted = 1000 * 10**18;
        uint256 usdRequired = (mtxWanted * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbRequired = (usdRequired * 1e8) / BNB_PRICE_USD;

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.InsufficientBNBBalance.selector);
        presale.buyExactMTX{value: .1 ether}(mtxWanted, modelId0);
    }

    function testBuyExactMTXRevertsWithZeroAmount() public {
        vm.warp(presaleStartTime + 1 days);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.buyExactMTX{value: 1 ether}(0, modelId0);
    }

    // ============ CLAIMTOKENS TESTS ============

    function testClaimTokensSixMonthLock() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy tokens
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        uint256 purchaseTime = block.timestamp;

        // Try to claim before unlock - should fail
        vm.warp(purchaseTime + SIX_MONTHS - 1 days);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.NoTokensToClaim.selector);
        presale.claim(0, 0);

        // Claim after 6 months
        vm.warp(purchaseTime + SIX_MONTHS + 1);
        uint256 balanceBefore = mtxToken.balanceOf(buyer1);

        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale2.TokensClaimed(
            buyer1,
            6000 * 10**18,
            0,
            modelId0
        );
        presale.claim(0, 0);

        assertEq(mtxToken.balanceOf(buyer1), 6000 * 10**18);
        assertEq(presale.totalClaimed(), 6000 * 10**18);

        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 6000) * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 6000 * 10**18);

        IMTXPresale2.Purchase memory purchaseAfter = getPurchase(buyer1, 0);
        assertEq(purchaseAfter.model, modelId0);
        assertEq(purchaseAfter.amount, 6000 * 10**18);
        assertTrue(purchaseAfter.claimed);
    }

    function testClaimTokensHalf3MHalf6M() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy tokens with modelId1 (3 months lock)
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId1);

        uint256 purchaseTime = block.timestamp;

        vm.warp(purchaseTime + THREE_MONTHS - 1 days);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.NoTokensToClaim.selector);
        presale.claim(0, 0);

        // Claim after 3 months
        vm.warp(purchaseTime + THREE_MONTHS + 1);

        vm.prank(buyer1);
        presale.claim(0, 0);
        assertEq(mtxToken.balanceOf(buyer1), 5000 * 10**18);
        assertEq(presale.totalClaimed(), 5000 * 10**18);
        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 5000) * 10**18);

        IMTXPresale2.Purchase memory purchaseAfter = getPurchase(buyer1, 0);
        assertEq(purchaseAfter.model, modelId1);
        assertEq(purchaseAfter.amount, 5000 * 10**18);
        assertTrue(purchaseAfter.claimed);
    }

    function testClaimTokensTwentyDayVesting() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy tokens with modelId2 (1 month lock)
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId2);

        uint256 purchaseTime = block.timestamp;
        
        vm.warp(purchaseTime + MONTH - 1 days);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.NoTokensToClaim.selector);
        presale.claim(0, 0);

        // Claim after 1 month
        vm.warp(purchaseTime + MONTH + 1);
        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale2.TokensClaimed(
            buyer1,
            3000 * 10**18,
            0,
            modelId2
        );
        presale.claim(0, 0);

        assertEq(mtxToken.balanceOf(buyer1), 3000 * 10**18);
        assertEq(presale.totalClaimed(), 3000 * 10**18);
        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 3000) * 10**18);

        IMTXPresale2.Purchase memory purchaseAfter = getPurchase(buyer1, 0);
        assertEq(purchaseAfter.model, modelId2);
        assertEq(purchaseAfter.amount, 3000 * 10**18);
        assertTrue(purchaseAfter.claimed);
    }

    function testClaimTokensWithTwentyAndHalfAfterThreeMonths() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy tokens with modelId2
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId2);

        // Buy tokens with modelId1
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId1);

        // Verify purchases
        
        uint256 purchaseTime = block.timestamp;
        uint256 expectedModel2Amount = 3000 * 10**18;
        uint256 expectedModel1Amount = 5000 * 10**18;
        
        // Try to claim before unlock - should fail
        vm.warp(purchaseTime + MONTH - 1 days);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.NoTokensToClaim.selector);
        presale.claim(0, 1);

        // Claim after 1 month (modelId2 unlocks)
        vm.warp(purchaseTime + MONTH + 1);
        
        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale2.TokensClaimed(
            buyer1,
            expectedModel2Amount,
            0,
            modelId2
        );
        presale.claim(0, 0);

        assertEq(mtxToken.balanceOf(buyer1), expectedModel2Amount);
        assertEq(presale.totalClaimed(), expectedModel2Amount);
        assertEq(address(presale).balance, 2 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 * 10**18 - expectedModel2Amount));

        IMTXPresale2.Purchase memory purchaseAfter1_0 = getPurchase(buyer1, 0);
        IMTXPresale2.Purchase memory purchaseAfter1_1 = getPurchase(buyer1, 1);

        assertEq(purchaseAfter1_0.claimed, true);
        assertEq(purchaseAfter1_1.claimed, false);

        // Claim after 3 months (modelId1 unlocks)
        vm.warp(purchaseTime + THREE_MONTHS + 1);

        vm.prank(buyer1);
        presale.claim(0, 2);

        assertEq(mtxToken.balanceOf(buyer1), expectedModel2Amount + expectedModel1Amount);
        assertEq(presale.totalClaimed(), expectedModel2Amount + expectedModel1Amount);

        IMTXPresale2.Purchase memory purchaseAfter2_0 = getPurchase(buyer1, 0);
        IMTXPresale2.Purchase memory purchaseAfter2_1 = getPurchase(buyer1, 1);
        assertEq(purchaseAfter2_0.claimed, true);
        assertEq(purchaseAfter2_1.claimed, true);

        // Try to claim again - should revert (no more tokens to claim)
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.NoTokensToClaim.selector);
        presale.claim(0, 4);
    }

    function testClaimTokensRevertsWithNoTokensToClaim() public {
        vm.warp(presaleEndTime + 6 * MONTH + 1);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.NoTokensToClaim.selector);
        presale.claim(0, 0);
    }

    function testClaimTokensWithRange() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy multiple times
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        uint256 purchaseTime = block.timestamp;

        // Claim only first purchase
        vm.warp(purchaseTime + SIX_MONTHS + 1);
        vm.prank(buyer1);
        presale.claim(0, 0);

        assertEq(mtxToken.balanceOf(buyer1), 18000 * 10**18);

        // Claim second purchase
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.NoTokensToClaim.selector);
        presale.claim(1, 1);
    }

    // ============ SETSALELIMIT TESTS ============

    function testSetSaleLimit() public {
        uint256 newLimit = 60_000_000 * 10**18;
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit IMTXPresale2.SaleLimitUpdated(50_000_000 * 10**18, newLimit);
        presale.setSaleLimit(newLimit);

        assertEq(presale.maxMTXSold(), newLimit);
    }

    function testSetSaleLimitRevertsForNonManager() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.CallerNotManager.selector);
        presale.setSaleLimit(60_000_000 * 10**18);
    }

    function testSetSaleLimitRevertsWithZero() public {
        vm.prank(manager);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.setSaleLimit(0);
    }

    function testSetSaleLimitRevertsBelowTotalSold() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 10 ether;
        uint256 expectedUsdValue = (bnbAmount * BNB_PRICE_USD) / 1e8;
        uint256 expectedMtxAmount = (expectedUsdValue * 1e18) / PRICE_SIX_MONTHS;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        vm.prank(manager);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.setSaleLimit(expectedMtxAmount - 1); // Less than total sold
    }

    // ============ SETPRESALEENDTIME TESTS ============

    function testSetPresaleEndTime() public {
        uint256 newEndTime = presaleEndTime + 10 days;
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit IMTXPresale2.PresaleEndTimeUpdated(presaleEndTime, newEndTime);
        presale.setPresaleEndTime(newEndTime);

        assertEq(presale.presaleEndTime(), newEndTime);
    }

    function testSetPresaleEndTimeRevertsForNonManager() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.CallerNotManager.selector);
        presale.setPresaleEndTime(presaleEndTime + 10 days);
    }

    function testSetPresaleEndTimeRevertsWithInvalidTime() public {
        vm.prank(manager);
        vm.expectRevert(IMTXPresale2.InvalidTime.selector);
        presale.setPresaleEndTime(presaleStartTime); // End <= Start
    }

    // ============ ADDLOCKMODEL TESTS ============

    function testAddLockModel() public {
        uint256 newPrice = 0.08e18;
        uint256 newLockDuration = 9 * MONTH;
        
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit IMTXPresale2.LockModelAdded(3, newPrice, newLockDuration, true);
        presale.addLockModel(newPrice, newLockDuration);

        (uint256 price, uint256 lockDuration, bool active) = presale.lockModels(3);
        assertEq(price, newPrice);
        assertEq(lockDuration, newLockDuration);
        assertTrue(active);
    }

    function testAddLockModelRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.CallerNotAdmin.selector);
        presale.addLockModel(0.08e18, 9 * MONTH);
    }

    function testAddLockModelRevertsWithZeroPrice() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.addLockModel(0, 9 * MONTH);
    }

    function testAddLockModelRevertsWithZeroDuration() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.addLockModel(0.08e18, 0);
    }

    // ============ UPDATELOCKMODEL TESTS ============

    function testUpdateLockModel() public {
        uint256 newPrice = 0.08e18;
        uint256 newLockDuration = 9 * MONTH;
        bool newActive = false;
        
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit IMTXPresale2.LockModelAdded(modelId0, newPrice, newLockDuration, newActive);
        presale.updateLockModel(modelId0, newPrice, newLockDuration, newActive);

        (uint256 price, uint256 lockDuration, bool active) = presale.lockModels(modelId0);
        assertEq(price, newPrice);
        assertEq(lockDuration, newLockDuration);
        assertFalse(active);
    }

    function testUpdateLockModelRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.CallerNotAdmin.selector);
        presale.updateLockModel(modelId0, 0.08e18, 9 * MONTH, false);
    }

    function testUpdateLockModelRevertsWithInvalidModel() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidPrice.selector);
        presale.updateLockModel(999, 0.08e18, 9 * MONTH, false);
    }

    function testUpdateLockModelRevertsWithZeroPrice() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.updateLockModel(modelId0, 0, 9 * MONTH, false);
    }

    function testUpdateLockModelRevertsWithZeroDuration() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.updateLockModel(modelId0, 0.08e18, 0, false);
    }

    // ============ SETBUYDISABLED TESTS ============

    function testSetBuyDisabled() public {
        assertFalse(presale.buyDisabled());
        
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit IMTXPresale2.BuyDisabledUpdated(true);
        presale.setBuyDisabled(true);
        
        assertTrue(presale.buyDisabled());
        
        vm.prank(manager);
        vm.expectEmit(false, false, false, true);
        emit IMTXPresale2.BuyDisabledUpdated(false);
        presale.setBuyDisabled(false);
        
        assertFalse(presale.buyDisabled());
    }

    function testSetBuyDisabledRevertsForNonManager() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.CallerNotManager.selector);
        presale.setBuyDisabled(true);
    }

    function testBuyExactBNBRevertsWhenDisabled() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Disable buying
        vm.prank(manager);
        presale.setBuyDisabled(true);
        
        // Try to buy
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.BuyDisabled.selector);
        presale.buyExactBNB{value: 1 ether}(modelId0);
    }

    function testBuyExactMTXRevertsWhenDisabled() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Disable buying
        vm.prank(manager);
        presale.setBuyDisabled(true);
        
        // Try to buy
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.BuyDisabled.selector);
        presale.buyExactMTX{value: 1 ether}(1000 * 10**18, modelId0);
    }

    function testBuyWorksAfterReenabling() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Disable buying
        vm.prank(manager);
        presale.setBuyDisabled(true);
        
        // Try to buy (should fail)
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.BuyDisabled.selector);
        presale.buyExactBNB{value: 1 ether}(modelId0);
        
        // Re-enable buying
        vm.prank(manager);
        presale.setBuyDisabled(false);
        
        // Buy should work now
        vm.prank(buyer1);
        presale.buyExactBNB{value: 1 ether}(modelId0);
        
        assertEq(presale.userTotalPurchased(buyer1), 6000 * 10**18);
    }

    // ============ MAXBUYPERUSER REVERT TESTS ============

    function testBuyExactBNBRevertsWhenMaxBuyPerUserExceeded() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Calculate BNB needed to buy exactly 10M tokens (the max limit)
        uint256 maxTokens = 10_000_000 * 10**18;
        uint256 usdNeeded = (maxTokens * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;
        
        vm.deal(buyer1, bnbNeeded + 1 ether);

        // First buy: buy exactly at the limit (should succeed)
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, modelId0);
        
        assertEq(presale.userTotalPurchased(buyer1), maxTokens);
        
        // Second buy: try to buy even 1 more token (should revert)
        uint256 oneMoreToken = 1 * 10**18;
        uint256 usdNeeded2 = (oneMoreToken * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded2 = (usdNeeded2 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded2 + 1 ether);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.MaxBuyPerUserExceeded.selector);
        presale.buyExactBNB{value: bnbNeeded2 + 1 ether}(modelId0);
    }

    function testBuyExactMTXRevertsWhenMaxBuyPerUserExceeded() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Calculate BNB needed to buy exactly 10M tokens (the max limit)
        uint256 maxTokens = 10_000_000 * 10**18;
        uint256 usdNeeded = (maxTokens * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded + 1 ether);
        // First buy: buy exactly at the limit (should succeed)
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, modelId0);
        
        assertEq(presale.userTotalPurchased(buyer1), maxTokens);
        
        // Second buy: try to buy even 1 more token (should revert)
        uint256 oneMoreToken = 1 * 10**18;
        uint256 usdNeeded2 = (oneMoreToken * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded2 = (usdNeeded2 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded2 + 1 ether);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.MaxBuyPerUserExceeded.selector);
        presale.buyExactMTX{value: bnbNeeded2 + 1 ether}(oneMoreToken, modelId0);
    }

    function testBuyExactBNBAllowsBuyingExactlyAtMaxBuyPerUser() public {
        vm.warp(presaleStartTime + 1 days);

        // Buy exactly at the max limit (should succeed)
        uint256 maxTokens = 10_000_000 * 10**18;
        uint256 usdNeeded = (maxTokens * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded + 1 ether);
        
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, modelId0);
        
        assertEq(presale.userTotalPurchased(buyer1), maxTokens);
    }

    function testBuyExactBNBAllowsMultiplePurchasesUpToMaxBuyPerUser() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Buy 5M tokens first
        uint256 firstBuy = 5_000_000 * 10**18;
        uint256 usdNeeded1 = (firstBuy * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded1 = (usdNeeded1 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded1 + 1 ether);
        
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded1 + 1 ether}(firstBuy, modelId0);
        
        assertEq(presale.userTotalPurchased(buyer1), firstBuy);
        
        // Buy another 5M tokens (should succeed, total = 10M)
        uint256 secondBuy = 5_000_000 * 10**18;
        uint256 usdNeeded2 = (secondBuy * PRICE_THREE_MONTHS) / 1e18;
        uint256 bnbNeeded2 = (usdNeeded2 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded2 + 1 ether);
        
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded2 + 1 ether}(secondBuy, modelId1);
        
        assertEq(presale.userTotalPurchased(buyer1), 10_000_000 * 10**18);
        
        // Try to buy even 1 more token (should revert)
        uint256 oneMoreToken = 1 * 10**18;
        uint256 usdNeeded3 = (oneMoreToken * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded3 = (usdNeeded3 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded3 + 1 ether);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.MaxBuyPerUserExceeded.selector);
        presale.buyExactBNB{value: bnbNeeded3 + 1 ether}(modelId0);
    }

    function testMaxBuyPerUserIsPerUserNotGlobal() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Buyer1 buys 10M tokens (should succeed)
        uint256 maxTokens = 10_000_000 * 10**18;
        uint256 usdNeeded = (maxTokens * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;
        
        vm.deal(buyer1, bnbNeeded + 1 ether);

        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, modelId0);
        
        assertEq(presale.userTotalPurchased(buyer1), maxTokens);

        vm.deal(buyer2, bnbNeeded + 1 ether);
        
        // Buyer2 should also be able to buy 10M tokens (limit is per user)
        vm.prank(buyer2);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, modelId0);
        
        assertEq(presale.userTotalPurchased(buyer2), maxTokens);
        assertEq(presale.totalMTXSold(), maxTokens * 2); // Both users bought
    }

    // ============ WITHDRAWBNB TESTS ============

    function testWithdrawBNB() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 5 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        assertEq(address(presale).balance, bnbAmount);

        address recipient = makeAddr("recipient");

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale2.BNBWithdrawn(recipient, bnbAmount);
        presale.withdrawBNB(recipient);

        assertEq(recipient.balance, bnbAmount);

        assertEq(address(presale).balance, 0);
    }

    function testWithdrawBNBRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.CallerNotAdmin.selector);
        presale.withdrawBNB(buyer1);
    }

    function testWithdrawBNBRevertsWithZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidAddress.selector);
        presale.withdrawBNB(address(0));
    }

    function testWithdrawBNBRevertsWithZeroBalance() public {
        address recipient = makeAddr("recipient");
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.withdrawBNB(recipient);
    }

    // ============ WITHDRAWMTXTOKENS TESTS ============

    function testWithdrawMTXTokens() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        // Transfer extra tokens to presale
        vm.prank(treasury);
        uint256 extraTokens = 10_000_000 * 10**18;
        mtxToken.transfer(address(presale), extraTokens);

        address recipient = makeAddr("recipient");
        uint256 balanceBefore = mtxToken.balanceOf(recipient);
        
        // Calculate actual withdrawable amount: balance - totalUnClaimed
        uint256 presaleBalance = mtxToken.balanceOf(address(presale));
        uint256 totalSold = presale.totalMTXSold();
        uint256 totalUnClaimed = totalSold - presale.totalClaimed();

        assertEq(totalSold, 6000 * 10**18);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale2.MTXTokensWithdrawn(recipient, presaleBalance - totalUnClaimed);
        presale.withdrawMTXTokens(recipient);

        assertEq(mtxToken.balanceOf(recipient), presaleBalance - totalUnClaimed);
    }

    function testWithdrawMTXTokensRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.CallerNotAdmin.selector);
        presale.withdrawMTXTokens(buyer1);
    }

    function testWithdrawMTXTokensRevertsWithZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidAddress.selector);
        presale.withdrawMTXTokens(address(0));
    }

    function testWithdrawMTXTokensRevertsWithNoWithdrawableAmount() public {
        vm.warp(presaleStartTime + 1 days);
        
        uint256 maxLimit = presale.maxMTXSold(); // 50M

        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale2.MaxBuyPerUserUpdated(10_000_000 * 10**18, maxLimit);
        presale.setMaxBuyPerUser(maxLimit);

        
        // Buy tokens to reach the max limit (50M tokens)
        uint256 tokensToBuy = maxLimit;
        uint256 usdNeeded = (tokensToBuy * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;
        
        // Fund buyer and buy the tokens
        vm.deal(buyer1, bnbNeeded + 1 ether);
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(tokensToBuy, modelId0);
        
        address recipient = makeAddr("recipient");
        
        vm.prank(admin);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.withdrawMTXTokens(recipient);
    }

    // ============ RECEIVE/FALLBACK TESTS ============

    function testReceiveReverts() public {
        // Test receive function - empty calldata triggers receive()
        // Using low-level call with empty data to trigger receive()
        (bool success, bytes memory returnData) = payable(address(presale)).call{value: 1 ether}("");
        
        // The call should revert, so success should be false
        assertFalse(success, "Receive should have reverted");
        
        // Verify the revert reason contains the expected message
        assertGt(returnData.length, 0, "Should have revert data");
    }

    function testFallbackReverts() public {
        // Test fallback function - non-empty calldata triggers fallback()
        (bool success, bytes memory returnData) = payable(address(presale)).call{value: 1 ether}(
            abi.encodeWithSignature("nonExistentFunction()")
        );
        
        // The call should revert, so success should be false
        assertFalse(success, "Fallback should have reverted");
        
        // Verify the revert reason contains the expected message
        assertGt(returnData.length, 0, "Should have revert data");
    }

    // ============ EDGE CASE TESTS ============

    function testMultiplePurchasesSameModel() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);
        uint256 firstAmount = presale.userTotalPurchased(buyer1);

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);
        uint256 secondAmount = presale.userTotalPurchased(buyer1);

        assertTrue(secondAmount > firstAmount);

        // Should create separate entries
        IMTXPresale2.Purchase memory purchase0 = getPurchase(buyer1, 0);
        IMTXPresale2.Purchase memory purchase1 = getPurchase(buyer1, 1);
        assertEq(purchase0.amount, 6000 * 10**18);
        assertEq(purchase1.amount, 6000 * 10**18);
    }

    function testPriceFeedWithZeroPrice() public {
        priceFeed.setPrice(int256(0));
        vm.warp(presaleStartTime + 1 days);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.InvalidPrice.selector);
        presale.buyExactBNB{value: 1 ether}(modelId0);
    }

    function testPriceFeedWithNegativePrice() public {
        priceFeed.setPrice(int256(-100));
        vm.warp(presaleStartTime + 1 days);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.InvalidPrice.selector);
        presale.buyExactBNB{value: 1 ether}(modelId0);
    }

    function testBuyExactBNBRevertsWithInactiveModel() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Deactivate model
        vm.prank(admin);
        presale.updateLockModel(modelId0, PRICE_SIX_MONTHS, SIX_MONTHS, false);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.InvalidModel.selector);
        presale.buyExactBNB{value: 1 ether}(modelId0);
    }

    function testBuyExactMTXRevertsWithInactiveModel() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Deactivate model
        vm.prank(admin);
        presale.updateLockModel(modelId0, PRICE_SIX_MONTHS, SIX_MONTHS, false);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.InvalidModel.selector);
        presale.buyExactMTX{value: 1 ether}(1000 * 10**18, modelId0);
    }

    function testClaimWithInvalidRange() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        uint256 purchaseTime = block.timestamp;
        vm.warp(purchaseTime + SIX_MONTHS + 1);

        // from > to should revert
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale2.InvalidAmount.selector);
        presale.claim(1, 0);
    }

    function testClaimWithOutOfRange() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(modelId0);

        uint256 purchaseTime = block.timestamp;
        vm.warp(purchaseTime + SIX_MONTHS + 1);

        // to >= purchases.length should default to last index
        vm.prank(buyer1);
        presale.claim(0, 999);
        
        assertEq(mtxToken.balanceOf(buyer1), 6000 * 10**18);
    }
}

