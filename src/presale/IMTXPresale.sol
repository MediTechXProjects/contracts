// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IMTXPresale
 * @notice Interface for MTXPresale contract
 */
interface IMTXPresale {

    enum LockModelType {
        SIX_MONTH_LOCK,      // Model 1
        HALF_3M_HALF_6M,     // Model 2 (50% at 3 months, 50% at 6 months)
        MONTHLY_VESTING   // Model 3 (20% in preSale end, 16% after 35 days, 16% every month)
    }
    struct Purchase {
        LockModelType model;
        uint256 mtxAmount;
        uint256 claimedAmount;
    }


    error PresaleNotStarted();
    error PresaleEnded();
    error PresaleNotEnded();
    error TokensNotUnlocked();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidTime();
    error InsufficientBNBBalance();
    error NoTokensToClaim();
    error CallerNotAdmin();
    error TransferFailed();
    error Paused();
    error SaleLimitExceeded();
    error InvalidModel();
    error InvalidPrice();
    error PresaleStarted();
    error RefundFailed();
    error MaxBuyPerUserExceeded();
    error BuyDisabled();

    event TokensPurchased(address indexed buyer, uint256 indexed bnbAmount, uint256 indexed mtxAmount, LockModelType model);
    event BuyDisabledUpdated(bool disabled);
    event TokensClaimed(address indexed user, uint256 indexed amount, LockModelType indexed model);
    event PresaleStartTimeUpdated(uint256 oldTime, uint256 newTime);
    event PresaleEndTimeUpdated(uint256 oldTime, uint256 newTime);
    event ListingTimeUpdated(uint256 oldTime, uint256 newTime);
    event BNBWithdrawn(address indexed to, uint256 amount);
    event MTXTokensWithdrawn(address indexed to, uint256 amount);
    event SaleLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event PriceUpdated(LockModelType model, uint256 oldPrice, uint256 newPrice);
    event MaxBuyPerUserUpdated(uint256 oldLimit, uint256 newLimit);

    function buyExactBNB(LockModelType model) external payable;
    function buyExactMTX(uint256 mtxWanted, LockModelType model) external payable;
    function claimTokens() external;
    function getUserLockedBalance(address user) external view returns (uint256);
    function getUserClaimedBalance(address user) external view returns (uint256);
    function getUserTotalPurchased(address user) external view returns (uint256);
    function getUserPurchases(address user) external view returns (Purchase[] memory);
    function setPresaleStartTime(uint256 _startTime) external;
    function setPresaleEndTime(uint256 _endTime) external;
    function setListingTime(uint256 _listingTime) external;
    function setSaleLimit(uint256 _saleLimit) external;
    function setPrice(LockModelType model, uint256 _price) external;
    function setBnbUsdPriceFeed(address _priceFeed) external;
    function setMaxBuyPerUser(uint256 _maxBuyPerUser) external;
    function withdrawBNB(address to) external;
    function withdrawMTXTokens(address to) external;
    function getPrice(LockModelType model) external view returns (uint256);
    function getPresaleStatus() external view returns (bool isActive, bool isEnded);
    function setBuyDisabled(bool _disabled) external;
}

