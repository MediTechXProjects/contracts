// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IMTXPresale
 * @notice Interface for MTXPresale contract
 */
interface IMTXPresale {
    error PresaleNotStarted();
    error PresaleEnded();
    error PresaleNotEnded();
    error TokensNotUnlocked();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidTime();
    error InsufficientUSDTBalance();
    error InsufficientUSDTAllowance();
    error NoTokensToClaim();
    error CallerNotAdmin();
    error TransferFailed();
    error Paused();
    error SaleLimitExceeded();

    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 mtxAmount);
    event TokensClaimed(address indexed user, uint256 amount);
    event PresaleStartTimeUpdated(uint256 oldTime, uint256 newTime);
    event PresaleEndTimeUpdated(uint256 oldTime, uint256 newTime);
    event UnlockTimeUpdated(uint256 oldTime, uint256 newTime);
    event USDTWithdrawn(address indexed to, uint256 amount);
    event MTXTokensWithdrawn(address indexed to, uint256 amount);
    event SaleLimitUpdated(uint256 oldLimit, uint256 newLimit);

    function buyTokens(uint256 usdtAmount) external;
    function claimTokens() external;
    function getUserLockedBalance(address user) external view returns (uint256);
    function getUserClaimedBalance(address user) external view returns (uint256);
    function setPresaleStartTime(uint256 _startTime) external;
    function setPresaleEndTime(uint256 _endTime) external;
    function setUnlockTime(uint256 _unlockTime) external;
    function setSaleLimit(uint256 _saleLimit) external;
    function withdrawUSDT(address to) external;
    function withdrawMTXTokens(address to) external;
}

