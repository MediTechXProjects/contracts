// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IMTXToken
 * @notice Interface for MTXToken contract
 */
interface IMTXToken is IERC20 {
    
    event Blacklisted(address indexed account, bool isBlacklisted);
    event Whitelisted(address indexed account, bool isWhitelisted);
    event RestrictionsDisabled();
    event TransferLimitsUpdated(uint256 maxWalletBalance, uint256 maxTransferAmount);
    event RateLimitingParamsUpdated(uint256 maxTxsPerWindow, uint256 windowSize, uint256 minTxInterval, uint256 maxTxsPerBlock);
    
    function blacklisted(address account) external view returns (bool);
    function whitelisted(address account) external view returns (bool);
    
    function addToBlacklist(address account) external;
    function removeFromBlacklist(address account) external;
    function addToWhitelist(address account) external;
    function removeFromWhitelist(address account) external;
    
    function restrictionsEnabled() external view returns (bool);
    function disableRestrictions() external;
    
    function mint(address to, uint256 amount) external;
    
    function setTransferLimits(uint256 _maxWalletBalance, uint256 _maxTransferAmount) external;
    function setRateLimitingParams(uint256 _maxTxsPerWindow, uint256 _windowSize, uint256 _minTxInterval, uint256 _maxTxsPerBlock) external;
}
