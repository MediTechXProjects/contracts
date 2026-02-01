// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IMTXPresale
 * @notice Interface for MTXPresale contract
 */
interface IMTXPresale2 {

    struct LockModel {
        uint256 price;
        uint256 lockDuration;
        bool active;
    }

    struct Purchase {
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
        uint256 model;
    }

    event TokensPurchased(address indexed buyer, uint256 indexed bnbAmount, uint256 indexed mtxAmount, uint256 model);
    event BuyDisabledUpdated(bool disabled);
    event TokensClaimed(address indexed user, uint256 indexed amount,uint256 indexed index, uint256 model);
    event PresaleStartTimeUpdated(uint256 oldTime, uint256 newTime);
    event PresaleEndTimeUpdated(uint256 oldTime, uint256 newTime);
    event ListingTimeUpdated(uint256 oldTime, uint256 newTime);
    event BNBWithdrawn(address indexed to, uint256 amount);
    event MTXTokensWithdrawn(address indexed to, uint256 amount);
    event SaleLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event PriceUpdated(uint256 model, uint256 oldPrice, uint256 newPrice);
    event MaxBuyPerUserUpdated(uint256 oldLimit, uint256 newLimit);
    event LockModelAdded(uint256 indexed modelId, uint256 indexed price, uint256 indexed lockDuration, bool active);
    
    error InvalidAmount();
    error InvalidAddress();
    error InvalidTime();
    error InvalidModel();
    error InvalidPrice();
    error SaleLimitExceeded();
    error MaxBuyPerUserExceeded();
    error PresaleNotActive();
    error BuyDisabled();
    error NoTokensToClaim();
    error TransferFailed();
    error CallerNotAdmin();
    error CallerNotManager();
    error InsufficientBNBBalance();
    error RefundFailed();

    function setSaleLimit(uint256 _saleLimit) external;
    function setPresaleEndTime(uint256 _endTime) external;
    function buyExactBNB(uint256 modelId) external payable;
    function buyExactMTX(uint256 mtxWanted, uint256 modelId) external payable;
    function claim(uint256 from, uint256 to) external;
    function addLockModel(uint256 price, uint256 lockDuration) external;
    function updateLockModel(uint256 modelId, uint256 price, uint256 lockDuration, bool active) external;
    function setMaxBuyPerUser(uint256 _maxBuyPerUser) external;
    function setBuyDisabled(bool _disabled) external;
    function withdrawBNB(address to) external;
    function withdrawMTXTokens(address to) external;
    function setMaxBuyTestModelUsd(uint256 _maxBuyTestModelUsd) external;


}

