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
        TWENTY_DAY_VESTING   // Model 3 (20% every 20 days)
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
    error ListingTimeNotSet();
    error PresaleStarted();

    event TokensPurchased(address indexed buyer, uint256 bnbAmount, uint256 mtxAmount, LockModelType model);
    event TokensClaimed(address indexed user, uint256 amount);
    event PresaleStartTimeUpdated(uint256 oldTime, uint256 newTime);
    event PresaleEndTimeUpdated(uint256 oldTime, uint256 newTime);
    event ListingTimeUpdated(uint256 oldTime, uint256 newTime);
    event BNBWithdrawn(address indexed to, uint256 amount);
    event MTXTokensWithdrawn(address indexed to, uint256 amount);
    event SaleLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event PriceUpdated(LockModelType model, uint256 oldPrice, uint256 newPrice);

    function buyTokens(LockModelType model) external payable;
    function claimTokens() external;
    function getUserLockedBalance(address user) external view returns (uint256);
    function getUserClaimedBalance(address user) external view returns (uint256);
    function getUserTotalPurchased(address user) external view returns (uint256);
    function setPresaleStartTime(uint256 _startTime) external;
    function setPresaleEndTime(uint256 _endTime) external;
    function setListingTime(uint256 _listingTime) external;
    function setSaleLimit(uint256 _saleLimit) external;
    function setPrice(LockModelType model, uint256 _price) external;
    function withdrawBNB(address to) external;
    function withdrawMTXTokens(address to) external;
    function getPrice(LockModelType model) external view returns (uint256);
}

