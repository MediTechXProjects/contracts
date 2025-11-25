// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IMTXToken } from "../mTXToken/IMTXToken.sol";
import { AccessRestriction } from "../accessRistriction/AccessRestriction.sol";
import { IMTXPresale } from "./IMTXPresale.sol";
import { ChainlinkPriceFeed } from "./ChainlinkPriceFeed.sol";

contract MTXPresale is IMTXPresale, ReentrancyGuard {

    AccessRestriction public accessRestriction;

    IERC20 public mtxToken;
    ChainlinkPriceFeed public bnbUsdPriceFeed;

    // Dynamic prices per model in USDT (with 18 decimals)
    mapping(LockModelType => uint256) public prices;

    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    uint256 public listingTime; // kept for compatibility but NOT used for unlock logic in this version

    // Purchase tracking
    struct Purchase {
        LockModelType model;
        uint256 mtxAmount;
        uint256 claimedAmount;
    }

    mapping(address => Purchase[]) public userPurchases;
    mapping(address => uint256) public userTotalPurchased;

    uint256 public totalBNBCollected;
    uint256 public totalMTXSold;
    uint256 public maxMTXSold = 50_000_000 * 10**18;
    // Time constants
    uint256 public constant MONTH = 30 days;
    uint256 public constant DAY_20 = 20 days;

    /**
     * @notice Modifier to restrict access to admin role
     */
    modifier onlyAdmin() {
        if (!accessRestriction.hasRole(accessRestriction.ADMIN_ROLE(), msg.sender)) {
            revert CallerNotAdmin();
        }
        _;
    }

    /**
     * @notice Modifier to check if presale is active
     */
    modifier onlyDuringPresale() {
        if (block.timestamp < presaleStartTime) revert PresaleNotStarted();
        if (block.timestamp >= presaleEndTime) revert PresaleEnded();
        _;
    }

    modifier onlyBeforePresaleStart() {
        if (block.timestamp >= presaleStartTime) revert PresaleStarted();
        _;
    }

    modifier notPaused() {
        if (accessRestriction.paused()) revert Paused();
        _;
    }

    constructor(
        address _mtxToken,
        address _accessRestriction,
        address _bnbUsdPriceFeed,
        uint256 _presaleStartTime,
        uint256 _presaleEndTime,
        uint256 _priceSixMonths,
        uint256 _priceThreeMonths,
        uint256 _priceTwentyDays
    ) {
        if (_mtxToken == address(0) || _accessRestriction == address(0) || _bnbUsdPriceFeed == address(0)) revert InvalidAddress();
        if (_presaleEndTime <= _presaleStartTime) revert InvalidTime();
        if (_priceSixMonths == 0 || _priceThreeMonths == 0 || _priceTwentyDays == 0) revert InvalidPrice();

        mtxToken = IERC20(_mtxToken);
        accessRestriction = AccessRestriction(_accessRestriction);
        bnbUsdPriceFeed = ChainlinkPriceFeed(_bnbUsdPriceFeed);

        presaleStartTime = _presaleStartTime;
        presaleEndTime = _presaleEndTime;

        // Set initial prices in USDT (with 18 decimals)
        prices[LockModelType.SIX_MONTH_LOCK] = _priceSixMonths;
        prices[LockModelType.HALF_3M_HALF_6M] = _priceThreeMonths;
        prices[LockModelType.TWENTY_DAY_VESTING] = _priceTwentyDays;
    }

    /**
     * @notice Buy MTX tokens with BNB
     * @param model Lock model (1, 2, or 3)
     */
    function buyTokens(LockModelType model) external payable override nonReentrant notPaused onlyDuringPresale {

        if (msg.value == 0) revert InvalidAmount();

        uint256 priceUsdt = prices[model];
        if (priceUsdt == 0) revert InvalidPrice();

        // Get BNB/USD price from Chainlink (returns price with 8 decimals)
        (, int256 bnbUsdPrice, , , ) = bnbUsdPriceFeed.latestRoundData();
        if (bnbUsdPrice <= 0) revert InvalidPrice();

        // Convert BNB sent to USD value
        // msg.value is in wei (18 decimals), bnbUsdPrice is in 8 decimals
        // USD value = (msg.value * bnbUsdPrice) / 10^8 (result in 18 decimals)
        uint256 usdValue = (msg.value * uint256(bnbUsdPrice)) / 1e8;

        // Calculate MTX amount: (USD value * 10^18) / priceUsdt
        // Both usdValue and priceUsdt are in 18 decimals
        uint256 mtxAmount = (usdValue * 1e18) / priceUsdt;

        if (mtxAmount == 0) revert InvalidAmount();

        if (totalMTXSold + mtxAmount > maxMTXSold) revert SaleLimitExceeded();

        Purchase[] storage purchases = userPurchases[msg.sender];

        bool found = false;

        for (uint256 i = 0; i < purchases.length; i++) {
            if (purchases[i].model == model) {
                purchases[i].mtxAmount += mtxAmount;
                found = true;
                break;
            }
        }

        if (!found) {
            purchases.push(Purchase({
                model: model,
                mtxAmount: mtxAmount,
                claimedAmount: 0
            }));
        }

        // Update tracking
        userTotalPurchased[msg.sender] += mtxAmount;
        totalBNBCollected += msg.value;
        totalMTXSold += mtxAmount;

        emit TokensPurchased(msg.sender, msg.value, mtxAmount, model);
    }

    /**
     * @notice Claim unlocked MTX tokens based on purchase models
     */
    function claimTokens() external override nonReentrant {
        Purchase[] storage purchases = userPurchases[msg.sender];
        uint256 totalClaimable = 0;

        for (uint256 i = 0; i < purchases.length; i++) {
            Purchase storage purchase = purchases[i];
            uint256 claimable = calculateClaimable(purchase);

            if (claimable > 0) {
                purchase.claimedAmount += claimable;
                totalClaimable += claimable;
            }
        }

        if (totalClaimable == 0) revert NoTokensToClaim();

        // Transfer MTX tokens to user (require success)
        bool success = mtxToken.transfer(msg.sender, totalClaimable);

        if (!success) revert TransferFailed();

        emit TokensClaimed(msg.sender, totalClaimable);
    }

    /**
     * @notice Calculate claimable amount for a purchase based on its model
     * @param purchase The purchase to calculate claimable amount for
     * @return claimable The amount that can be claimed
     *
     * NOTE: Unlock times are calculated from presaleEndTime (not purchaseTime).
     */
    function calculateClaimable(Purchase memory purchase) public view returns (uint256) {
        uint256 remaining = purchase.mtxAmount - purchase.claimedAmount;
        if (remaining == 0) return 0;

        uint256 currentTime = block.timestamp;

        if (purchase.model == LockModelType.SIX_MONTH_LOCK) {
            // Model 1: All tokens unlock after 6 months from presale end
            uint256 unlockTime = presaleEndTime + (6 * MONTH);
            if (currentTime >= unlockTime) {
                return remaining;
            }
        } else if (purchase.model == LockModelType.HALF_3M_HALF_6M) {
            // Model 2: 50% at 3 months, 50% at 6 months (from presale end)
            uint256 threeMonths = presaleEndTime + (3 * MONTH);
            uint256 sixMonths = presaleEndTime + (6 * MONTH);

            uint256 firstHalf = purchase.mtxAmount / 2;

            if (currentTime >= sixMonths) {
                return remaining; // All unlocked
            } else if (currentTime >= threeMonths) {
                if (purchase.claimedAmount < firstHalf) {
                    return firstHalf - purchase.claimedAmount;
                }
            }
        } else if (purchase.model == LockModelType.TWENTY_DAY_VESTING) {
            // Model 3: 20% every 20 days, starting at presaleEndTime (first 20% at presale end)

            if (currentTime < presaleEndTime) return 0;

            uint256 periods = (currentTime - presaleEndTime) / DAY_20;

            // +1 because first 20% is available at period 0 (presaleEndTime)
            uint256 unlockedPortions = periods + 1;
            if (unlockedPortions > 5) unlockedPortions = 5;

            uint256 totalUnlocked = (purchase.mtxAmount * unlockedPortions) / 5;
            if (totalUnlocked > purchase.mtxAmount) totalUnlocked = purchase.mtxAmount;

            if (totalUnlocked > purchase.claimedAmount) {
                return totalUnlocked - purchase.claimedAmount;
            }
        }

        return 0;
    }

    /**
     * @notice Get user's locked (unclaimed) balance
     * @param user Address of the user
     * @return Locked balance
     */
    function getUserLockedBalance(address user) external view override returns (uint256) {
        Purchase[] memory purchases = userPurchases[user];
        uint256 totalLocked = 0;

        for (uint256 i = 0; i < purchases.length; i++) {
            uint256 remaining = purchases[i].mtxAmount - purchases[i].claimedAmount;
            totalLocked += remaining;
        }

        return totalLocked;
    }

    /**
     * @notice Get user's total claimed balance
     * @param user Address of the user
     * @return Claimed balance
     */
    function getUserClaimedBalance(address user) external view override returns (uint256) {
        Purchase[] memory purchases = userPurchases[user];
        uint256 totalClaimed = 0;

        for (uint256 i = 0; i < purchases.length; i++) {
            totalClaimed += purchases[i].claimedAmount;
        }

        return totalClaimed;
    }

    /**
     * @notice Get user's total purchased amount
     * @param user Address of the user
     * @return Total purchased amount
     */
    function getUserTotalPurchased(address user) external view override returns (uint256) {
        return userTotalPurchased[user];
    }

    /**
     * @notice Get price for a specific model
     * @param model Lock model (1, 2, or 3)
     * @return Price in wei
     */
    function getPrice(LockModelType model) external view override returns (uint256) {
        return prices[model];
    }

    /**
     * @notice Get user's purchases
     * @param user Address of the user
     * @return Array of purchases
     */
    function getUserPurchases(address user) external view returns (Purchase[] memory) {
        return userPurchases[user];
    }

    /**
     * @notice Set presale start time (admin only)
     * @param _startTime Timestamp when presale starts
     */
    function setPresaleStartTime(uint256 _startTime) external override onlyAdmin {
        if (_startTime >= presaleEndTime) revert InvalidTime();

        uint256 oldTime = presaleStartTime;
        presaleStartTime = _startTime;

        emit PresaleStartTimeUpdated(oldTime, _startTime);
    }

    /**
     * @notice Set presale end time (admin only)
     * @param _endTime Timestamp when presale ends
     */
    function setPresaleEndTime(uint256 _endTime) external override onlyAdmin {
        if (_endTime <= presaleStartTime) revert InvalidTime();

        uint256 oldTime = presaleEndTime;
        presaleEndTime = _endTime;

        emit PresaleEndTimeUpdated(oldTime, _endTime);
    }

    /**
     * @notice Set listing time for Model 3 tokens (admin only)
     * @dev kept for compatibility but NOT used in unlock calculations in this version
     * @param _listingTime Timestamp when listing occurs
     */
    function setListingTime(uint256 _listingTime) external override onlyAdmin {
        uint256 oldTime = listingTime;
        listingTime = _listingTime;

        emit ListingTimeUpdated(oldTime, _listingTime);
    }

    /**
     * @notice Set price for a specific model (admin only)
     * @param model Lock model (1, 2, or 3)
     * @param _price New price in USDT (with 18 decimals)
     */
    function setPrice(LockModelType model, uint256 _price) external override onlyAdmin {
        if (_price == 0) revert InvalidPrice();

        uint256 oldPrice = prices[model];
        prices[model] = _price;

        emit PriceUpdated(model, oldPrice, _price);
    }

    /**
     * @notice Set BNB/USD price feed address (admin only)
     * @param _priceFeed Address of Chainlink BNB/USD price feed
     */
    function setBnbUsdPriceFeed(address _priceFeed) external onlyAdmin {
        if (_priceFeed == address(0)) revert InvalidAddress();
        bnbUsdPriceFeed = ChainlinkPriceFeed(_priceFeed);
    }

    /**
     * @notice Get current BNB/USD price from Chainlink
     * @return price BNB/USD price with 8 decimals
     */
    function getBnbUsdPrice() external view returns (uint256 price) {
        (, int256 bnbUsdPrice, , , ) = bnbUsdPriceFeed.latestRoundData();
        if (bnbUsdPrice <= 0) revert InvalidPrice();
        return uint256(bnbUsdPrice);
    }

    /**
     * @notice Set sale limit for MTX tokens (admin only)
     * @param _saleLimit Maximum amount of MTX tokens that can be sold
     */
    function setSaleLimit(uint256 _saleLimit) external override onlyAdmin {
        if (_saleLimit == 0 || _saleLimit < totalMTXSold || _saleLimit < maxMTXSold) revert InvalidAmount();

        uint256 oldLimit = maxMTXSold;
        maxMTXSold = _saleLimit;

        emit SaleLimitUpdated(oldLimit, _saleLimit);
    }

    /**
     * @notice Withdraw collected BNB (admin only)
     * @param to Address to send BNB to
     */
    function withdrawBNB(address to) external override onlyAdmin {
        if (to == address(0)) revert InvalidAddress();

        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidAmount();

        (bool success, ) = payable(to).call{value: balance}("");
        if (!success) revert TransferFailed();

        emit BNBWithdrawn(to, balance);
    }

    /**
     * @notice Withdraw remaining MTX tokens (admin only)
     * @notice Can only withdraw after presale ends and only unsold tokens (balance - totalMTXSold)
     * @param to Address to send MTX tokens to
     */
    function withdrawMTXTokens(address to) external override onlyAdmin {
        if (to == address(0)) revert InvalidAddress();
        if (block.timestamp < presaleEndTime) revert PresaleNotEnded();

        uint256 balance = mtxToken.balanceOf(address(this));

        uint256 withdrawableAmount = balance > totalMTXSold ? balance - totalMTXSold : 0;

        if (withdrawableAmount == 0) revert InvalidAmount();

        bool ok = mtxToken.transfer(to, withdrawableAmount);
        if (!ok) revert TransferFailed();

        emit MTXTokensWithdrawn(to, withdrawableAmount);
    }

    /**
     * @notice Get presale status
     * @return isActive True if presale is currently active
     * @return isEnded True if presale has ended
     * @return listingTimeSet True if listing time is set (kept for compatibility)
     */
    function getPresaleStatus() external view returns (bool isActive, bool isEnded, bool listingTimeSet) {
        uint256 currentTime = block.timestamp;
        isActive = currentTime >= presaleStartTime && currentTime < presaleEndTime;
        isEnded = currentTime >= presaleEndTime;
        listingTimeSet = listingTime > 0;
    }

    /**
     * @notice Receive function to accept BNB
     */
    receive() external payable {
        revert("Use buyTokens() function");
    }

    /**
     * @notice Fallback function
     */
    fallback() external payable {
        revert("Use buyTokens() function");
    }
}
