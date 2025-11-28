// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test,console} from "forge-std/Test.sol";
import {MTXPresale} from "../src/presale/MTXPresale.sol";
import {IMTXPresale} from "../src/presale/IMTXPresale.sol";
import {MTXToken} from "../src/mTXToken/MTXToken.sol";
import {AccessRestriction} from "../src/accessRistriction/AccessRestriction.sol";
import {MockChainlinkPriceFeed} from "../src/mock/MockChainlinkPriceFeed.sol";
import {MockLayerZeroEndpointV2} from "../src/mock/MockLayerZeroEndpointV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MTXPresaleTest is Test {
    MTXPresale public presale;
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

    uint256 public presaleStartTime;
    uint256 public presaleEndTime;

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

        // Deploy Presale
        presale = new MTXPresale(
            address(mtxToken),
            address(accessRestriction),
            address(priceFeed),
            presaleStartTime,
            presaleEndTime,
            PRICE_SIX_MONTHS,
            PRICE_THREE_MONTHS,
            PRICE_MONTHLY_VESTING
        );
        
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

    function testConstructor() public view {
        assertEq(address(presale.mtxToken()), address(mtxToken));
        assertEq(address(presale.accessRestriction()), address(accessRestriction));
        assertEq(address(presale.bnbUsdPriceFeed()), address(priceFeed));
        assertEq(presale.presaleStartTime(), presaleStartTime);
        assertEq(presale.presaleEndTime(), presaleEndTime);
        assertEq(presale.getPrice(IMTXPresale.LockModelType.SIX_MONTH_LOCK), PRICE_SIX_MONTHS);
        assertEq(presale.getPrice(IMTXPresale.LockModelType.HALF_3M_HALF_6M), PRICE_THREE_MONTHS);
        assertEq(presale.getPrice(IMTXPresale.LockModelType.MONTHLY_VESTING), PRICE_MONTHLY_VESTING);
        assertEq(presale.maxMTXSold(), 50_000_000 * 10**18);
    }

    function testConstructorRevertsWithZeroAddress() public {
        vm.expectRevert(IMTXPresale.InvalidAddress.selector);
        new MTXPresale(
            address(0),
            address(accessRestriction),
            address(priceFeed),
            presaleStartTime,
            presaleEndTime,
            PRICE_SIX_MONTHS,
            PRICE_THREE_MONTHS,
            PRICE_MONTHLY_VESTING
        );
    }

    function testConstructorRevertsWithInvalidTime() public {
        vm.expectRevert(IMTXPresale.InvalidTime.selector);
        new MTXPresale(
            address(mtxToken),
            address(accessRestriction),
            address(priceFeed),
            presaleEndTime,
            presaleStartTime, // end before start
            PRICE_SIX_MONTHS,
            PRICE_THREE_MONTHS,
            PRICE_MONTHLY_VESTING
        );
    }

    function testConstructorRevertsWithZeroPrice() public {
        vm.expectRevert(IMTXPresale.InvalidPrice.selector);
        new MTXPresale(
            address(mtxToken),
            address(accessRestriction),
            address(priceFeed),
            presaleStartTime,
            presaleEndTime,
            0, // zero price
            PRICE_THREE_MONTHS,
            PRICE_MONTHLY_VESTING
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
        emit IMTXPresale.TokensPurchased(
            buyer1,
            bnbAmount,
            expectedMtxAmount,
            IMTXPresale.LockModelType.SIX_MONTH_LOCK
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        assertEq(presale.userTotalPurchased(buyer1), 6000 * 10**18);
        assertEq(presale.totalBNBCollected(), 1 ether);
        assertEq(presale.totalMTXSold(), 6000 * 10**18);
        
        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);

        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.SIX_MONTH_LOCK));
        assertEq(purchases[0].mtxAmount, 6000 * 10**18);
        assertEq(purchases[0].claimedAmount, 0);
    }

    function testBuyExactBNBWithDifferentModels() public {
        vm.warp(presaleStartTime + 10 days);
        uint256 bnbAmount = 1 ether;
        // Buy with SIX_MONTH_LOCK
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            IMTXPresale.LockModelType.SIX_MONTH_LOCK
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        presale.userTotalPurchased(buyer1);

        vm.warp(presaleStartTime + 21 days);

        // Buy with HALF_3M_HALF_6M
        vm.prank(buyer2);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer2,
            1 ether,
            5000 * 10**18,
            IMTXPresale.LockModelType.HALF_3M_HALF_6M
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.HALF_3M_HALF_6M);
        presale.userTotalPurchased(buyer2);

        // Buy with TWENTY_DAY_VESTING
        vm.prank(buyer3);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer3,
            1 ether,
            3000 * 10**18,
            IMTXPresale.LockModelType.MONTHLY_VESTING
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.MONTHLY_VESTING);
        presale.userTotalPurchased(buyer3);

        assertEq(presale.totalBNBCollected(), 3 ether);
        assertEq(presale.totalMTXSold(), 14000 * 10**18);
        assertEq(address(presale).balance, 3 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);
        assertEq(mtxToken.balanceOf(buyer2), 0);
        assertEq(mtxToken.balanceOf(buyer3), 0);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.SIX_MONTH_LOCK));
        assertEq(purchases[0].mtxAmount, 6000 * 10**18);
        assertEq(purchases[0].claimedAmount, 0);

        purchases = presale.getUserPurchases(buyer2);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.HALF_3M_HALF_6M));
        assertEq(purchases[0].mtxAmount, 5000 * 10**18);
        assertEq(purchases[0].claimedAmount, 0);

        purchases = presale.getUserPurchases(buyer3);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[0].mtxAmount, 3000 * 10**18);
        assertEq(purchases[0].claimedAmount, 0);
    }

    function testBuyExactBNBOneUserDifferentModels() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        
        // One user buys with SIX_MONTH_LOCK
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            IMTXPresale.LockModelType.SIX_MONTH_LOCK
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        // Same user buys with HALF_3M_HALF_6M
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            1 ether,
            5000 * 10**18,
            IMTXPresale.LockModelType.HALF_3M_HALF_6M
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.HALF_3M_HALF_6M);

        // Same user buys with TWENTY_DAY_VESTING
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            1 ether,
            3000 * 10**18,
            IMTXPresale.LockModelType.MONTHLY_VESTING
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.MONTHLY_VESTING);

        // Verify totals
        assertEq(presale.userTotalPurchased(buyer1), 14000 * 10**18); // 6000 + 5000 + 3000
        assertEq(presale.totalBNBCollected(), 3 ether);
        assertEq(presale.totalMTXSold(), 14000 * 10**18);
        assertEq(address(presale).balance, 3 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        // Verify user has 3 separate purchases (one for each model)
        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 3);
        
        // Check first purchase (SIX_MONTH_LOCK)
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.SIX_MONTH_LOCK));
        assertEq(purchases[0].mtxAmount, 6000 * 10**18);
        assertEq(purchases[0].claimedAmount, 0);
        
        // Check second purchase (HALF_3M_HALF_6M)
        assertEq(uint256(purchases[1].model), uint256(IMTXPresale.LockModelType.HALF_3M_HALF_6M));
        assertEq(purchases[1].mtxAmount, 5000 * 10**18);
        assertEq(purchases[1].claimedAmount, 0);
        
        // Check third purchase (TWENTY_DAY_VESTING)
        assertEq(uint256(purchases[2].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[2].mtxAmount, 3000 * 10**18);
        assertEq(purchases[2].claimedAmount, 0);

        assertEq(presale.getUserLockedBalance(buyer1), 14000 * 10**18);
    }

    function testBuyExactBNBSameModelThreeTimes() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        
        // User buys SIX_MONTH_LOCK model first time
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            IMTXPresale.LockModelType.SIX_MONTH_LOCK
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        uint256 firstPurchase = presale.userTotalPurchased(buyer1);
        assertEq(firstPurchase, 6000 * 10**18);

        // Same user buys SIX_MONTH_LOCK model second time
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            IMTXPresale.LockModelType.SIX_MONTH_LOCK
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        uint256 secondPurchase = presale.userTotalPurchased(buyer1);
        assertEq(secondPurchase, 12000 * 10**18); // 6000 + 6000

        // Same user buys SIX_MONTH_LOCK model third time
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            1 ether,
            6000 * 10**18,
            IMTXPresale.LockModelType.SIX_MONTH_LOCK
        );
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        uint256 thirdPurchase = presale.userTotalPurchased(buyer1);
        assertEq(thirdPurchase, 18000 * 10**18); // 6000 + 6000 + 6000

        // Verify totals
        assertEq(presale.totalBNBCollected(), 3 ether);
        assertEq(presale.totalMTXSold(), 18000 * 10**18);
        assertEq(address(presale).balance, 3 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        // Verify user has only 1 purchase entry (same model purchases are merged)
        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.SIX_MONTH_LOCK));
        assertEq(purchases[0].mtxAmount, 18000 * 10**18); // All three purchases merged
        assertEq(purchases[0].claimedAmount, 0);
    }

    function testBuyExactBNBRevertsBeforePresaleStart() public {
        vm.warp(presaleStartTime - 1);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.PresaleNotStarted.selector);
        presale.buyExactBNB{value: 1 ether}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testBuyExactBNBRevertsAfterPresaleEnd() public {
        vm.warp(presaleEndTime);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.PresaleEnded.selector);
        presale.buyExactBNB{value: 1 ether}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testBuyExactBNBRevertsWithZeroValue() public {
        vm.warp(presaleStartTime + 1 days);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.InvalidAmount.selector);
        presale.buyExactBNB{value: 0}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testBuyExactBNBRevertsWhenPaused() public {
        vm.warp(presaleStartTime + 1 days);
        vm.prank(admin);
        accessRestriction.pause();

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.Paused.selector);
        presale.buyExactBNB{value: 1 ether}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testBuyExactBNBRevertsWhenSaleLimitExceeded() public {
        vm.warp(presaleStartTime + 1 days);
        // Set a very low sale limit
        vm.prank(admin);
        presale.setSaleLimit(1 ether);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.SaleLimitExceeded.selector);
        presale.buyExactBNB{value: 5 ether}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    // ============ BUYEXACTMTX TESTS ============

    function testBuyExactMTX() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 mtxWanted = 1000 * 10**18;
        uint256 usdRequired = (mtxWanted * PRICE_THREE_MONTHS) / 1e18;
        uint256 bnbRequired = (usdRequired * 1e8) / BNB_PRICE_USD;

        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            0.2 ether,
            mtxWanted,
            IMTXPresale.LockModelType.HALF_3M_HALF_6M
        );
        presale.buyExactMTX{value: 1 ether}(mtxWanted, IMTXPresale.LockModelType.HALF_3M_HALF_6M);

        assertEq(presale.userTotalPurchased(buyer1), mtxWanted);
        assertEq(presale.totalBNBCollected(), 0.2 ether);
        assertEq(presale.totalMTXSold(), mtxWanted);
        assertEq(address(presale).balance, 0.2 ether);
        assertEq(mtxToken.balanceOf(address(presale)), 50_000_000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 0);

        assertEq(buyer1.balance, 999.8 ether);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.HALF_3M_HALF_6M));
        assertEq(purchases[0].mtxAmount, mtxWanted);
        assertEq(purchases[0].claimedAmount, 0);
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
        presale.buyExactMTX{value: bnbSent}(mtxWanted, IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        uint256 balanceAfter = buyer1.balance;
        assertEq(balanceBefore - balanceAfter, bnbRequired); // Only required amount deducted
    }

    function testBuyExactMTXOneUserDifferentModels() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Calculate BNB required for each model with same MTX amount
        uint256 mtxWanted = 1000 * 10**18;
        
        // Buy with SIX_MONTH_LOCK
        uint256 usdRequired1 = (mtxWanted * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbRequired1 = (usdRequired1 * 1e8) / BNB_PRICE_USD;

        console.log(bnbRequired1);
        
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            bnbRequired1,
            mtxWanted,
            IMTXPresale.LockModelType.SIX_MONTH_LOCK
        );
        presale.buyExactMTX{value: 1 ether}(mtxWanted, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        uint256 firstPurchase = presale.userTotalPurchased(buyer1);
        assertEq(firstPurchase, mtxWanted);

        // Buy with HALF_3M_HALF_6M
        uint256 usdRequired2 = (mtxWanted * PRICE_THREE_MONTHS) / 1e18;
        uint256 bnbRequired2 = (usdRequired2 * 1e8) / BNB_PRICE_USD;
        
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            bnbRequired2,
            mtxWanted,
            IMTXPresale.LockModelType.HALF_3M_HALF_6M
        );
        presale.buyExactMTX{value: 1 ether}(mtxWanted, IMTXPresale.LockModelType.HALF_3M_HALF_6M);
        
        uint256 secondPurchase = presale.userTotalPurchased(buyer1);
        assertEq(secondPurchase, mtxWanted * 2); // 1000 + 1000

        // Buy with TWENTY_DAY_VESTING
        uint256 usdRequired3 = (mtxWanted * PRICE_MONTHLY_VESTING) / 1e18;
        uint256 bnbRequired3 = (usdRequired3 * 1e8) / BNB_PRICE_USD;
        
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit IMTXPresale.TokensPurchased(
            buyer1,
            bnbRequired3,
            mtxWanted,
            IMTXPresale.LockModelType.MONTHLY_VESTING
        );
        presale.buyExactMTX{value: 1 ether}(mtxWanted, IMTXPresale.LockModelType.MONTHLY_VESTING);
        
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
        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 3);
        
        // Check first purchase (SIX_MONTH_LOCK)
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.SIX_MONTH_LOCK));
        assertEq(purchases[0].mtxAmount, mtxWanted);
        assertEq(purchases[0].claimedAmount, 0);
        
        // Check second purchase (HALF_3M_HALF_6M)
        assertEq(uint256(purchases[1].model), uint256(IMTXPresale.LockModelType.HALF_3M_HALF_6M));
        assertEq(purchases[1].mtxAmount, mtxWanted);
        assertEq(purchases[1].claimedAmount, 0);
        
        // Check third purchase (TWENTY_DAY_VESTING)
        assertEq(uint256(purchases[2].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[2].mtxAmount, mtxWanted);
        assertEq(purchases[2].claimedAmount, 0);
    }

    function testBuyExactMTXRevertsWithInsufficientBNB() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 mtxWanted = 1000 * 10**18;
        uint256 usdRequired = (mtxWanted * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbRequired = (usdRequired * 1e8) / BNB_PRICE_USD;

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.InsufficientBNBBalance.selector);
        presale.buyExactMTX{value: .1 ether}(mtxWanted, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testBuyExactMTXRevertsWithZeroAmount() public {
        vm.warp(presaleStartTime + 1 days);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.InvalidAmount.selector);
        presale.buyExactMTX{value: 1 ether}(0, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    // ============ CLAIMTOKENS TESTS ============

    function testClaimTokensSixMonthLock() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy tokens
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        // Try to claim before unlock - should fail
        vm.warp(presaleEndTime + 5 * MONTH);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.NoTokensToClaim.selector);
        presale.claimTokens();

        // Claim after 6 months
        vm.warp(presaleEndTime + 6 * MONTH + 1);
        uint256 balanceBefore = mtxToken.balanceOf(buyer1);

        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.TokensClaimed(
            buyer1,
            6000 * 10**18,
            IMTXPresale.LockModelType.SIX_MONTH_LOCK
        );
        presale.claimTokens();

        assertEq(mtxToken.balanceOf(buyer1), 6000 * 10**18);
        assertEq(presale.getUserClaimedBalance(buyer1), 6000 * 10**18);

        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 6000) * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 6000 * 10**18);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.SIX_MONTH_LOCK));
        assertEq(purchases[0].mtxAmount, 6000 * 10**18);
        assertEq(purchases[0].claimedAmount, 6000 * 10**18);
    }

    function testClaimTokensHalf3MHalf6M() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy tokens
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.HALF_3M_HALF_6M);

        vm.warp(presaleEndTime + 1 * MONTH + 1);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.NoTokensToClaim.selector);
        presale.claimTokens();

        // Claim first half at 3 months
        vm.warp(presaleEndTime + 3 * MONTH + 1);

        vm.prank(buyer1);
        presale.claimTokens();
        assertEq(presale.getUserClaimedBalance(buyer1), 2500 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 2500 * 10**18);
        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 2500) * 10**18);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.NoTokensToClaim.selector);
        presale.claimTokens();



        // Claim second half at 6 months
        vm.warp(presaleEndTime + 6 * MONTH + 1);
        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.TokensClaimed(
            buyer1,
            2500 * 10**18,
            IMTXPresale.LockModelType.HALF_3M_HALF_6M
        );
        presale.claimTokens();
        assertEq(presale.getUserClaimedBalance(buyer1), 5000 * 10**18);

        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 5000) * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 5000 * 10**18);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.HALF_3M_HALF_6M));
        assertEq(purchases[0].mtxAmount, 5000 * 10**18);
        assertEq(purchases[0].claimedAmount, 5000 * 10**18);
    }

    function testClaimTokensTwentyDayVesting() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy tokens
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.MONTHLY_VESTING);

        vm.warp(presaleEndTime - 1);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.NoTokensToClaim.selector);
        presale.claimTokens();

        // Claim first 20% at presale end
        vm.warp(presaleEndTime + 1);
        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.TokensClaimed(
            buyer1,
            600 * 10**18,
            IMTXPresale.LockModelType.MONTHLY_VESTING
        );
        presale.claimTokens();

        assertEq(presale.getUserClaimedBalance(buyer1), 600 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 600 * 10**18);
        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 600) * 10**18);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[0].mtxAmount, 3000 * 10**18);
        assertEq(purchases[0].claimedAmount, 600 * 10**18);

        // Claim second 20% after 20 days
        vm.warp(presaleEndTime + 33 days);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.NoTokensToClaim.selector);
        presale.claimTokens();


        vm.warp(presaleEndTime + 35 days + 1);

        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.TokensClaimed(
            buyer1,
            480 * 10**18,
            IMTXPresale.LockModelType.MONTHLY_VESTING
        );
        presale.claimTokens();
        assertEq(presale.getUserClaimedBalance(buyer1), 1080 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 1080 * 10**18);

        purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[0].mtxAmount, 3000 * 10**18);
        assertEq(purchases[0].claimedAmount, 1080 * 10**18);

        vm.warp(presaleEndTime + 35 days + 1 * MONTH + 1);

        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.TokensClaimed(
            buyer1,
            480 * 10**18,
            IMTXPresale.LockModelType.MONTHLY_VESTING
        );
        presale.claimTokens();
        
        assertEq(presale.getUserClaimedBalance(buyer1), 1560 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 1560 * 10**18);
        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 1560) * 10**18);

        purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[0].mtxAmount, 3000 * 10**18);
        assertEq(purchases[0].claimedAmount, 1560 * 10**18);


        vm.warp(presaleEndTime + 35 days + 4 * MONTH + 1);

        vm.prank(buyer1);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.TokensClaimed(
            buyer1,
            1440 * 10**18,
            IMTXPresale.LockModelType.MONTHLY_VESTING
        );
        presale.claimTokens();
        assertEq(presale.getUserClaimedBalance(buyer1), 3000 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 3000 * 10**18);
        assertEq(address(presale).balance, 1 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 3000) * 10**18);

        purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[0].mtxAmount, 3000 * 10**18);
        assertEq(purchases[0].claimedAmount, 3000 * 10**18);
    }

    function testClaimTokensWithTwentyAndHalfAfterThreeMonths() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        // Buy tokens with TWENTY_DAY_VESTING model
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.MONTHLY_VESTING);

        // Buy tokens with HALF_3M_HALF_6M model
        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.HALF_3M_HALF_6M);

        // Verify purchases
        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 2);
        
        uint256 expectedTwentyAmount = 3000 * 10**18;
        uint256 expectedHalfAmount = 5000 * 10**18;
        
        uint256 expectedClaimableAfter3Months = expectedTwentyAmount + (expectedHalfAmount / 2); // 3000 + 2500 = 5500

        // Try to claim before 3 months - should fail or claim partial
        vm.warp(presaleEndTime + 2 * MONTH + 1);
        
        vm.prank(buyer1);
        presale.claimTokens();

        assertEq(presale.getUserClaimedBalance(buyer1), 1080 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 1080 * 10**18);
        assertEq(address(presale).balance, 2 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 1080) * 10**18);

        purchases = presale.getUserPurchases(buyer1);

        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[0].mtxAmount, 3000 * 10**18);
        assertEq(purchases[0].claimedAmount, 1080 * 10**18);

        assertEq(uint256(purchases[1].model), uint256(IMTXPresale.LockModelType.HALF_3M_HALF_6M));
        assertEq(purchases[1].mtxAmount, 5000 * 10**18);
        assertEq(purchases[1].claimedAmount, 0);


        // Claim after 3 months
        vm.warp(presaleEndTime + 3 * MONTH + 1);


        vm.prank(buyer1);
        presale.claimTokens();

        assertEq(presale.getUserClaimedBalance(buyer1), 4060 * 10**18);
        assertEq(mtxToken.balanceOf(buyer1), 4060 * 10**18);
        assertEq(address(presale).balance, 2 ether);
        assertEq(mtxToken.balanceOf(address(presale)), (50_000_000 - 4060) * 10**18);

        purchases = presale.getUserPurchases(buyer1);

        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.MONTHLY_VESTING));
        assertEq(purchases[0].mtxAmount, 3000 * 10**18);
        assertEq(purchases[0].claimedAmount, 1560 * 10**18);

        assertEq(uint256(purchases[1].model), uint256(IMTXPresale.LockModelType.HALF_3M_HALF_6M));
        assertEq(purchases[1].mtxAmount, 5000 * 10**18);
        assertEq(purchases[1].claimedAmount, 2500 * 10**18);


        // Try to claim again - should revert (no more tokens to claim at 3 months)
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.NoTokensToClaim.selector);
        presale.claimTokens();
    }

    function testClaimTokensRevertsWithNoTokensToClaim() public {
        vm.warp(presaleEndTime + 6 * MONTH + 1);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.NoTokensToClaim.selector);
        presale.claimTokens();
    }

    // ============ CALCULATECLAIMABLE TESTS ============

    function testCalculateClaimableSixMonthLock() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        uint256 expectedUsdValue = (bnbAmount * BNB_PRICE_USD) / 1e8;
        uint256 expectedMtxAmount = (expectedUsdValue * 1e18) / PRICE_SIX_MONTHS;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);

        // Before unlock
        vm.warp(presaleEndTime + 5 * MONTH);
        assertEq(presale.calculateClaimable(purchases[0]), 0);

        // After unlock
        vm.warp(presaleEndTime + 6 * MONTH + 1);
        assertEq(presale.calculateClaimable(purchases[0]), expectedMtxAmount);
    }

    function testCalculateClaimableHalf3MHalf6M() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        uint256 expectedUsdValue = (bnbAmount * BNB_PRICE_USD) / 1e8;
        uint256 expectedMtxAmount = (expectedUsdValue * 1e18) / PRICE_THREE_MONTHS;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.HALF_3M_HALF_6M);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);

        // At 3 months - first half
        vm.warp(presaleEndTime + 3 * MONTH + 1);
        assertEq(presale.calculateClaimable(purchases[0]), expectedMtxAmount / 2);

        // At 6 months - all
        vm.warp(presaleEndTime + 6 * MONTH + 1);
        assertEq(presale.calculateClaimable(purchases[0]), expectedMtxAmount);
    }

    function testCalculateClaimableTwentyDayVesting() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.MONTHLY_VESTING);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);

        // At presale end - 20%
        vm.warp(presaleEndTime + 1);
        assertEq(presale.calculateClaimable(purchases[0]), 600 * 10**18);

        // After 40 days - 60%
        vm.warp(presaleEndTime + 2 * MONTH + 1);
        assertEq(presale.calculateClaimable(purchases[0]), 1080 * 10**18);
    }

    // ============ GETUSERLOCKEDBALANCE TESTS ============

    function testGetUserLockedBalance() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        uint256 expectedUsdValue = (bnbAmount * BNB_PRICE_USD) / 1e8;
        uint256 expectedMtxAmount = (expectedUsdValue * 1e18) / PRICE_SIX_MONTHS;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        assertEq(presale.getUserLockedBalance(buyer1), expectedMtxAmount);

        // After claiming
        vm.warp(presaleEndTime + 6 * MONTH + 1);
        vm.prank(buyer1);
        presale.claimTokens();

        assertEq(presale.getUserLockedBalance(buyer1), 0);
    }

    function testGetUserLockedBalanceWithMultiplePurchases() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.HALF_3M_HALF_6M);

        uint256 totalPurchased = presale.getUserTotalPurchased(buyer1);
        assertEq(presale.getUserLockedBalance(buyer1), totalPurchased);
    }

    function testGetUserLockedBalanceForNonExistentUser() public {
        assertEq(presale.getUserLockedBalance(buyer1), 0);
    }

    // ============ GETUSERCLAIMEDBALANCE TESTS ============

    function testGetUserClaimedBalance() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        uint256 expectedUsdValue = (bnbAmount * BNB_PRICE_USD) / 1e8;
        uint256 expectedMtxAmount = (expectedUsdValue * 1e18) / PRICE_SIX_MONTHS;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        assertEq(presale.getUserClaimedBalance(buyer1), 0);

        vm.warp(presaleEndTime + 6 * MONTH + 1);
        vm.prank(buyer1);
        presale.claimTokens();

        assertEq(presale.getUserClaimedBalance(buyer1), expectedMtxAmount);
    }

    function testGetUserClaimedBalanceForNonExistentUser() public {
        assertEq(presale.getUserClaimedBalance(buyer1), 0);
    }

    // ============ GETUSERTOTALPURCHASED TESTS ============

    function testGetUserTotalPurchased() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;
        uint256 expectedUsdValue = (bnbAmount * BNB_PRICE_USD) / 1e8;
        uint256 expectedMtxAmount = (expectedUsdValue * 1e18) / PRICE_SIX_MONTHS;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        assertEq(presale.getUserTotalPurchased(buyer1), expectedMtxAmount);
    }

    function testGetUserTotalPurchasedWithMultiplePurchases() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        uint256 firstPurchase = presale.getUserTotalPurchased(buyer1);

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        uint256 secondPurchase = presale.getUserTotalPurchased(buyer1);

        assertTrue(secondPurchase > firstPurchase);
    }

    // ============ GETUSERPURCHASES TESTS ============

    function testGetUserPurchases() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1);
        assertEq(uint256(purchases[0].model), uint256(IMTXPresale.LockModelType.SIX_MONTH_LOCK));
    }

    function testGetUserPurchasesWithMultipleModels() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.HALF_3M_HALF_6M);

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.MONTHLY_VESTING);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 3);
    }

    function testGetUserPurchasesMergesSameModel() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        uint256 firstAmount = presale.getUserTotalPurchased(buyer1);

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1); // Same model should merge
        assertTrue(presale.getUserTotalPurchased(buyer1) > firstAmount);
    }

    // ============ GETPRICE TESTS ============

    function testGetPrice() public {
        assertEq(presale.getPrice(IMTXPresale.LockModelType.SIX_MONTH_LOCK), PRICE_SIX_MONTHS);
        assertEq(presale.getPrice(IMTXPresale.LockModelType.HALF_3M_HALF_6M), PRICE_THREE_MONTHS);
        assertEq(presale.getPrice(IMTXPresale.LockModelType.MONTHLY_VESTING), PRICE_MONTHLY_VESTING);
    }

    // ============ SETPRESALESTARTTIME TESTS ============

    function testSetPresaleStartTime() public {
        uint256 newStartTime = block.timestamp + 2 days;
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit IMTXPresale.PresaleStartTimeUpdated(presaleStartTime, newStartTime);
        presale.setPresaleStartTime(newStartTime);

        assertEq(presale.presaleStartTime(), newStartTime);
    }

    function testSetPresaleStartTimeRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.CallerNotAdmin.selector);
        presale.setPresaleStartTime(block.timestamp + 2 days);
    }

    function testSetPresaleStartTimeRevertsWithInvalidTime() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidTime.selector);
        presale.setPresaleStartTime(presaleEndTime); // Start >= End
    }

    function testSetPresaleStartTimeRevertsWithPresaleStarted() public {
        vm.warp(presaleStartTime + 1 days + 1);
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.PresaleStarted.selector);
        presale.setPresaleStartTime(presaleStartTime + 2 days); // Start < End
    }

    // ============ SETPRESALEENDTIME TESTS ============

    function testSetPresaleEndTime() public {
        uint256 newEndTime = presaleEndTime + 10 days;
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit IMTXPresale.PresaleEndTimeUpdated(presaleEndTime, newEndTime);
        presale.setPresaleEndTime(newEndTime);

        assertEq(presale.presaleEndTime(), newEndTime);
    }

    function testSetPresaleEndTimeRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.CallerNotAdmin.selector);
        presale.setPresaleEndTime(presaleEndTime + 10 days);
    }

    function testSetPresaleEndTimeRevertsWithInvalidTime() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidTime.selector);
        presale.setPresaleEndTime(presaleStartTime); // End <= Start
    }

    function testSetPresaleEndTimeRevertsWithPresaleStarted() public {
        vm.warp(presaleStartTime + 1 days + 1);
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.PresaleStarted.selector);
        presale.setPresaleEndTime(presaleStartTime + 2 days); // Start < End
    }

    // ============ SETPRICE TESTS ============

    function testSetPrice() public {
        uint256 newPrice = 0.08e18;
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.PriceUpdated(
            IMTXPresale.LockModelType.SIX_MONTH_LOCK,
            PRICE_SIX_MONTHS,
            newPrice
        );
        presale.setPrice(IMTXPresale.LockModelType.SIX_MONTH_LOCK, newPrice);

        assertEq(presale.getPrice(IMTXPresale.LockModelType.SIX_MONTH_LOCK), newPrice);
    }

    function testSetPriceRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.CallerNotAdmin.selector);
        presale.setPrice(IMTXPresale.LockModelType.SIX_MONTH_LOCK, 0.08e18);
    }

    function testSetPriceRevertsWithZeroPrice() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidPrice.selector);
        presale.setPrice(IMTXPresale.LockModelType.SIX_MONTH_LOCK, 0);
    }

    function testSetPriceRevertsWithPresaleStarted() public {
        vm.warp(presaleStartTime + 1 days + 1);
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.PresaleStarted.selector);
        presale.setPrice(IMTXPresale.LockModelType.SIX_MONTH_LOCK, 0.08e18);
    }

    // ============ SETBNBUSDPRICEFEED TESTS ============

    function testSetBnbUsdPriceFeed() public {
        MockChainlinkPriceFeed newPriceFeed = new MockChainlinkPriceFeed(int256(400e8));
        vm.prank(admin);
        presale.setBnbUsdPriceFeed(address(newPriceFeed));

        assertEq(address(presale.bnbUsdPriceFeed()), address(newPriceFeed));
    }

    function testSetBnbUsdPriceFeedRevertsForNonAdmin() public {
        MockChainlinkPriceFeed newPriceFeed = new MockChainlinkPriceFeed(int256(400e8));
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.CallerNotAdmin.selector);
        presale.setBnbUsdPriceFeed(address(newPriceFeed));
    }

    function testSetBnbUsdPriceFeedRevertsWithZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidAddress.selector);
        presale.setBnbUsdPriceFeed(address(0));
    }

    // ============ SETSALELIMIT TESTS ============

    function testSetSaleLimit() public {
        uint256 newLimit = 60_000_000 * 10**18;
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit IMTXPresale.SaleLimitUpdated(50_000_000 * 10**18, newLimit);
        presale.setSaleLimit(newLimit);

        assertEq(presale.maxMTXSold(), newLimit);
    }

    function testSetSaleLimitRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.CallerNotAdmin.selector);
        presale.setSaleLimit(60_000_000 * 10**18);
    }

    function testSetSaleLimitRevertsWithZero() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidAmount.selector);
        presale.setSaleLimit(0);
    }

    function testSetSaleLimitRevertsBelowTotalSold() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 10 ether;
        uint256 expectedUsdValue = (bnbAmount * BNB_PRICE_USD) / 1e8;
        uint256 expectedMtxAmount = (expectedUsdValue * 1e18) / PRICE_SIX_MONTHS;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidAmount.selector);
        presale.setSaleLimit(expectedMtxAmount - 1); // Less than total sold
    }

    // ============ SETMAXBUYPERUSER TESTS ============

    function testSetMaxBuyPerUser() public {
        uint256 newLimit = 20_000_000 * 10**18;
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit IMTXPresale.MaxBuyPerUserUpdated(10_000_000 * 10**18, newLimit);
        presale.setMaxBuyPerUser(newLimit);

        assertEq(presale.maxBuyPerUser(), newLimit);
    }

    function testSetMaxBuyPerUserRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.CallerNotAdmin.selector);
        presale.setMaxBuyPerUser(20_000_000 * 10**18);
    }

    function testSetMaxBuyPerUserRevertsWithZero() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidAmount.selector);
        presale.setMaxBuyPerUser(0);
    }

    function testSetMaxBuyPerUserRevertsWithPresaleStarted() public {
        vm.warp(presaleStartTime + 1 days + 1);
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.PresaleStarted.selector);
        presale.setMaxBuyPerUser(20_000_000 * 10**18);
    }

    function testConstructorSetsDefaultMaxBuyPerUser() public view {
        assertEq(presale.maxBuyPerUser(), 10_000_000 * 10**18);
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
        
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        assertEq(presale.userTotalPurchased(buyer1), maxTokens);
        
        // Second buy: try to buy even 1 more token (should revert)
        uint256 oneMoreToken = 1 * 10**18;
        uint256 usdNeeded2 = (oneMoreToken * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded2 = (usdNeeded2 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded2 + 1 ether);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.MaxBuyPerUserExceeded.selector);
        presale.buyExactBNB{value: bnbNeeded2 + 1 ether}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
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
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        assertEq(presale.userTotalPurchased(buyer1), maxTokens);
        
        // Second buy: try to buy even 1 more token (should revert)
        uint256 oneMoreToken = 1 * 10**18;
        uint256 usdNeeded2 = (oneMoreToken * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded2 = (usdNeeded2 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded2 + 1 ether);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.MaxBuyPerUserExceeded.selector);
        presale.buyExactMTX{value: bnbNeeded2 + 1 ether}(oneMoreToken, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testBuyExactBNBRevertsWhenSinglePurchaseExceedsMaxBuyPerUser() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Try to buy more than 10M tokens in a single purchase
        uint256 tokensToBuy = 10_000_001 * 10**18; // 1 token over the limit
        uint256 usdNeeded = (tokensToBuy * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;


        vm.deal(buyer1, bnbNeeded + 1 ether);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.MaxBuyPerUserExceeded.selector);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(tokensToBuy, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testBuyExactBNBAllowsBuyingExactlyAtMaxBuyPerUser() public {
        vm.warp(presaleStartTime + 1 days);

        // Buy exactly at the max limit (should succeed)
        uint256 maxTokens = 10_000_000 * 10**18;
        uint256 usdNeeded = (maxTokens * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded + 1 ether);
        
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
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
        presale.buyExactMTX{value: bnbNeeded1 + 1 ether}(firstBuy, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        assertEq(presale.userTotalPurchased(buyer1), firstBuy);
        
        // Buy another 5M tokens (should succeed, total = 10M)
        uint256 secondBuy = 5_000_000 * 10**18;
        uint256 usdNeeded2 = (secondBuy * PRICE_THREE_MONTHS) / 1e18;
        uint256 bnbNeeded2 = (usdNeeded2 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded2 + 1 ether);
        
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded2 + 1 ether}(secondBuy, IMTXPresale.LockModelType.HALF_3M_HALF_6M);
        
        assertEq(presale.userTotalPurchased(buyer1), 10_000_000 * 10**18);
        
        // Try to buy even 1 more token (should revert)
        uint256 oneMoreToken = 1 * 10**18;
        uint256 usdNeeded3 = (oneMoreToken * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded3 = (usdNeeded3 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded3 + 1 ether);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.MaxBuyPerUserExceeded.selector);
        presale.buyExactBNB{value: bnbNeeded3 + 1 ether}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testBuyExactBNBWithDifferentModelsRespectsMaxBuyPerUser() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Buy 5M tokens with SIX_MONTH_LOCK
        uint256 firstBuy = 5_000_000 * 10**18;
        uint256 usdNeeded1 = (firstBuy * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded1 = (usdNeeded1 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded1 + 1 ether);
        
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded1 + 1 ether}(firstBuy, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        // Buy 4M tokens with HALF_3M_HALF_6M (total = 9M, should succeed)
        uint256 secondBuy = 4_000_000 * 10**18;
        uint256 usdNeeded2 = (secondBuy * PRICE_THREE_MONTHS) / 1e18;
        uint256 bnbNeeded2 = (usdNeeded2 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded2 + 1 ether);
        
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded2 + 1 ether}(secondBuy, IMTXPresale.LockModelType.HALF_3M_HALF_6M);
        
        assertEq(presale.userTotalPurchased(buyer1), 9_000_000 * 10**18);
        
        // Try to buy 2M more tokens (would exceed 10M limit, should revert)
        uint256 thirdBuy = 2_000_000 * 10**18;
        uint256 usdNeeded3 = (thirdBuy * PRICE_MONTHLY_VESTING) / 1e18;
        uint256 bnbNeeded3 = (usdNeeded3 * 1e8) / BNB_PRICE_USD;

        vm.deal(buyer1, bnbNeeded3 + 1 ether);
        
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.MaxBuyPerUserExceeded.selector);
        presale.buyExactMTX{value: bnbNeeded3 + 1 ether}(thirdBuy, IMTXPresale.LockModelType.MONTHLY_VESTING);
    }

    function testMaxBuyPerUserIsPerUserNotGlobal() public {
        vm.warp(presaleStartTime + 1 days);
        
        // Buyer1 buys 10M tokens (should succeed)
        uint256 maxTokens = 10_000_000 * 10**18;
        uint256 usdNeeded = (maxTokens * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;
        
        vm.deal(buyer1, bnbNeeded + 1 ether);

        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        assertEq(presale.userTotalPurchased(buyer1), maxTokens);

        vm.deal(buyer2, bnbNeeded + 1 ether);
        
        // Buyer2 should also be able to buy 10M tokens (limit is per user)
        vm.prank(buyer2);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(maxTokens, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        assertEq(presale.userTotalPurchased(buyer2), maxTokens);
        assertEq(presale.totalMTXSold(), maxTokens * 2); // Both users bought
    }

    // ============ WITHDRAWBNB TESTS ============

    function testWithdrawBNB() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 5 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        assertEq(address(presale).balance, bnbAmount);

        address recipient = makeAddr("recipient");

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.BNBWithdrawn(recipient, bnbAmount);
        presale.withdrawBNB(recipient);

        assertEq(recipient.balance, bnbAmount);

        assertEq(address(presale).balance, 0);
    }

    function testWithdrawBNBRevertsForNonAdmin() public {
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.CallerNotAdmin.selector);
        presale.withdrawBNB(buyer1);
    }

    function testWithdrawBNBRevertsWithZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidAddress.selector);
        presale.withdrawBNB(address(0));
    }

    function testWithdrawBNBRevertsWithZeroBalance() public {
        address recipient = makeAddr("recipient");
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidAmount.selector);
        presale.withdrawBNB(recipient);
    }

    // ============ WITHDRAWMTXTOKENS TESTS ============

    function testWithdrawMTXTokens() public {
        vm.warp(presaleStartTime + 1 days);
        uint256 bnbAmount = 1 ether;

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);

        // Transfer extra tokens to presale
        vm.prank(treasury);
        uint256 extraTokens = 10_000_000 * 10**18;
        mtxToken.transfer(address(presale), extraTokens);

        vm.warp(presaleEndTime + 1);
        address recipient = makeAddr("recipient");
        uint256 balanceBefore = mtxToken.balanceOf(recipient);
        
        // Calculate actual withdrawable amount: balance - totalMTXSold
        uint256 presaleBalance = mtxToken.balanceOf(address(presale));
        uint256 totalSold = presale.totalMTXSold();

        assertEq(totalSold, 6000 * 10**18);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit IMTXPresale.MTXTokensWithdrawn(recipient, (60_000_000 - 6000) * 10**18);
        presale.withdrawMTXTokens(recipient);

        assertEq(mtxToken.balanceOf(recipient), (60_000_000 - 6000) * 10**18);
    }

    function testWithdrawMTXTokensRevertsBeforePresaleEnd() public {
        vm.warp(presaleStartTime + 1 days);
        address recipient = makeAddr("recipient");
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.PresaleNotEnded.selector);
        presale.withdrawMTXTokens(recipient);
    }

    function testWithdrawMTXTokensRevertsForNonAdmin() public {
        vm.warp(presaleEndTime + 1);
        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.CallerNotAdmin.selector);
        presale.withdrawMTXTokens(buyer1);
    }

    function testWithdrawMTXTokensRevertsWithZeroAddress() public {
        vm.warp(presaleEndTime + 1);
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidAddress.selector);
        presale.withdrawMTXTokens(address(0));
    }

    function testWithdrawMTXTokensRevertsWithNoWithdrawableAmount() public {

        vm.prank(admin);
        presale.setMaxBuyPerUser(50_000_000 * 10**18);

        vm.warp(presaleStartTime + 1 days);
        
        uint256 maxLimit = presale.maxMTXSold(); // 50M
        
        // Buy tokens to reach the max limit (50M tokens)
        uint256 tokensToBuy = maxLimit;
        uint256 usdNeeded = (tokensToBuy * PRICE_SIX_MONTHS) / 1e18;
        uint256 bnbNeeded = (usdNeeded * 1e8) / BNB_PRICE_USD;
        
        // Fund buyer and buy the tokens
        vm.deal(buyer1, bnbNeeded + 1 ether);
        vm.prank(buyer1);
        presale.buyExactMTX{value: bnbNeeded + 1 ether}(tokensToBuy, IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        
        vm.warp(presaleEndTime + 1);
        address recipient = makeAddr("recipient");
        
        uint256 finalBalance = mtxToken.balanceOf(address(presale));
        uint256 finalTotalSold = presale.totalMTXSold();
        
        vm.prank(admin);
        vm.expectRevert(IMTXPresale.InvalidAmount.selector);
        presale.withdrawMTXTokens(recipient);
    }

    // ============ GETPRESALESTATUS TESTS ============

    function testGetPresaleStatusBeforeStart() public view {
        (bool isActive, bool isEnded) = presale.getPresaleStatus();
        assertFalse(isActive);
        assertFalse(isEnded);
    }

    function testGetPresaleStatusDuringPresale() public {
        vm.warp(presaleStartTime + 1 days);
        (bool isActive, bool isEnded) = presale.getPresaleStatus();
        assertTrue(isActive);
        assertFalse(isEnded);
    }

    function testGetPresaleStatusAfterEnd() public {
        vm.warp(presaleEndTime + 1);
        (bool isActive, bool isEnded) = presale.getPresaleStatus();
        assertFalse(isActive);
        assertTrue(isEnded);
    }

    // ============ RECEIVE/FALLBACK TESTS ============

    function testReceiveReverts() public {
        // Test receive function - empty calldata triggers receive()
        // Using low-level call with empty data to trigger receive()
        (bool success, bytes memory returnData) = payable(address(presale)).call{value: 1 ether}("");
        
        // The call should revert, so success should be false
        assertFalse(success, "Receive should have reverted");
        
        // Verify the revert reason contains the expected message
        // The revert data for Error(string) is: 0x08c379a0 (selector) + offset + length + string
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
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        uint256 firstAmount = presale.getUserTotalPurchased(buyer1);

        vm.prank(buyer1);
        presale.buyExactBNB{value: bnbAmount}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
        uint256 secondAmount = presale.getUserTotalPurchased(buyer1);

        assertTrue(secondAmount > firstAmount);

        IMTXPresale.Purchase[] memory purchases = presale.getUserPurchases(buyer1);
        assertEq(purchases.length, 1); // Should merge
        assertEq(purchases[0].mtxAmount, secondAmount);
    }

    function testPriceFeedWithZeroPrice() public {
        priceFeed.setPrice(int256(0));
        vm.warp(presaleStartTime + 1 days);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.InvalidPrice.selector);
        presale.buyExactBNB{value: 1 ether}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }

    function testPriceFeedWithNegativePrice() public {
        priceFeed.setPrice(int256(-100));
        vm.warp(presaleStartTime + 1 days);

        vm.prank(buyer1);
        vm.expectRevert(IMTXPresale.InvalidPrice.selector);
        presale.buyExactBNB{value: 1 ether}(IMTXPresale.LockModelType.SIX_MONTH_LOCK);
    }
}

