// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IMTXToken } from "./IMTXToken.sol";
import { AccessRestriction } from "../accessRistriction/AccessRestriction.sol";
import "forge-std/console.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract MTXToken is OFT, ERC20Burnable, ERC20Permit, IMTXToken {
    // Access restriction contract
    AccessRestriction public immutable accessRestriction;
    
    // Maximum supply of 10 billion tokens
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10**18; // 10 billion tokens
    
    // Transfer limits (based on 10 billion total supply)
    uint256 public maxWalletBalance = 100_000_000 * 10**18; // 1% of 10 billion (100 million tokens)
    uint256 public maxTransferAmount = 5_000_000 * 10**18;  // 0.05% of 10 billion (5 million tokens)


    // Blacklist mapping
    mapping(address => bool) public override blacklisted;
    
    // Whitelist mapping - whitelisted addresses bypass all checks
    mapping(address => bool) public override whitelisted;
    
    
    // Rate limiting control flags
    bool public checkTxInterval = true;
    bool public checkBlockTxLimit = true;
    bool public checkWindowTxLimit = true;
    bool public checkBlackList = true;
    bool public checkMaxTransfer = true;
    bool public checkMaxWalletBalance = true;
    
    // Control flag for all checks (can only be disabled once by admin)
    bool public override restrictionsEnabled = true;
    
    
    // Rate limiting parameters
    uint256 public maxTxsPerWindow = 3; // Max transactions per 15 minutes
    uint256 public windowSize = 15 minutes; // 15 minute window
    uint256 public minTxInterval = 1 minutes; // Minimum time between transactions
    uint256 public maxTxsPerBlock = 2; // Max transactions per block
    
    // Rate limiting state
    struct RateLimit {
        uint256 windowStart;
        uint256 txCount;
        uint256 lastTxTime;
        uint256 lastTxBlock;
        uint256 blockTxCount;
    }
    
    mapping(address => RateLimit) private rateLimits;
    
    /**
     * @notice Modifier to restrict access to manager role
     */
    modifier onlyManager() {
        require(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), _msgSender()), "MTXToken: caller is not a manager");
        _;
    }

    /**
     * @notice Modifier to restrict access to admin role
     */
    modifier onlyAdmin() {
        require(accessRestriction.hasRole(0x00, _msgSender()), "MTXToken: caller is not an admin");
        _;
    }

    /**
     * @notice Modifier to restrict access to treasury role
     */
    modifier onlyTreasury() {
        require(accessRestriction.hasRole(accessRestriction.TREASURY_ROLE(), _msgSender()), "MTXToken: caller is not treasury");
        _;
    }

    constructor(
        address _lzEndpoint,
        address _owner,
        address _accessRestriction
    ) OFT("mtx-token","MTX", _lzEndpoint, _owner) Ownable(_owner) ERC20Permit("mtx-token") {
        accessRestriction = AccessRestriction(_accessRestriction);
    }

    /**
     * @notice Mint tokens to a specified address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyTreasury {
        require(totalSupply() + amount <= MAX_SUPPLY, "MTXToken: minting would exceed max supply");
        _mint(to, amount);
    }

    /**
     * @notice Add an address to the blacklist
     * @param account The address to blacklist
     */
    function addToBlacklist(address account) external override onlyManager {
        blacklisted[account] = true;
        emit Blacklisted(account, true);
    }

    /**
     * @notice Remove an address from the blacklist
     * @param account The address to remove from blacklist
     */
    function removeFromBlacklist(address account) external override onlyManager {
        blacklisted[account] = false;
        emit Blacklisted(account, false);
    }

    /**
     * @notice Add an address to the whitelist
     * @param account The address to whitelist
     */
    function addToWhitelist(address account) external override onlyManager {
        whitelisted[account] = true;
        emit Whitelisted(account, true);
    }

    /**
     * @notice Remove an address from the whitelist
     * @param account The address to remove from whitelist
     */
    function removeFromWhitelist(address account) external override onlyManager {
        whitelisted[account] = false;
        emit Whitelisted(account, false);
    }

    /**
     * @notice Enable or disable transaction interval check
     * @param enabled True to enable interval check, false to disable
     */
    function setCheckTxInterval(bool enabled) external onlyManager {
        checkTxInterval = enabled;
    }

    /**
     * @notice Enable or disable block transaction limit check
     * @param enabled True to enable block limit check, false to disable
     */
    function setCheckBlockTxLimit(bool enabled) external onlyManager {
        checkBlockTxLimit = enabled;
    }

    /**
     * @notice Enable or disable window transaction limit check
     * @param enabled True to enable window limit check, false to disable
     */
    function setCheckWindowTxLimit(bool enabled) external onlyManager {
        checkWindowTxLimit = enabled;
    }

    /**
     * @notice Enable or disable blacklist check
     * @param enabled True to enable blacklist check, false to disable
     */
    function setCheckBlackList(bool enabled) external onlyManager {
        checkBlackList = enabled;
    }

    /**
     * @notice Enable or disable maximum transfer amount check
     * @param enabled True to enable max transfer check, false to disable
     */
    function setCheckMaxTransfer(bool enabled) external onlyManager {
        checkMaxTransfer = enabled;
    }

    /**
     * @notice Enable or disable maximum wallet balance check
     * @param enabled True to enable max wallet balance check, false to disable
     */
    function setCheckMaxWalletBalance(bool enabled) external onlyManager {
        checkMaxWalletBalance = enabled;
    }

    /**
     * @notice Set transfer limits (wallet balance and transfer amount)
     * @param _maxWalletBalance Maximum wallet balance allowed
     * @param _maxTransferAmount Maximum transfer amount allowed
     */
    function setTransferLimits(uint256 _maxWalletBalance, uint256 _maxTransferAmount) external onlyManager {
   
        require(_maxWalletBalance > 0, "MTXToken: max wallet balance must be greater than 0");
        require(_maxTransferAmount > 0, "MTXToken: max transfer amount must be greater than 0");
        
        maxWalletBalance = _maxWalletBalance;
        maxTransferAmount = _maxTransferAmount;
        
        emit TransferLimitsUpdated(_maxWalletBalance, _maxTransferAmount);
    }

    /**
     * @notice Set rate limiting parameters
     * @param _maxTxsPerWindow Maximum transactions per window
     * @param _windowSize Window size in seconds
     * @param _minTxInterval Minimum time between transactions in seconds
     * @param _maxTxsPerBlock Maximum transactions per block
     */
    function setRateLimitingParams(
        uint256 _maxTxsPerWindow,
        uint256 _windowSize,
        uint256 _minTxInterval,
        uint256 _maxTxsPerBlock
    ) external onlyManager {
        
        maxTxsPerWindow = _maxTxsPerWindow;
        windowSize = _windowSize;
        minTxInterval = _minTxInterval;
        maxTxsPerBlock = _maxTxsPerBlock;
        
        emit RateLimitingParamsUpdated(_maxTxsPerWindow, _windowSize, _minTxInterval, _maxTxsPerBlock);
    }

    /**
     * @notice Permanently disable all restrictions (one-time only, admin only)
     * This function can only be called once and makes the token fully unrestricted
     */
    function disableRestrictions() override external onlyAdmin {
        require(restrictionsEnabled, "already disabled");
        restrictionsEnabled = false;
        emit RestrictionsDisabled();
    }

    /**
     * @notice Private function to check and update rate limits for an address
     * @param from The address to check rate limits for
     */
    function _checkRateLimit(address from) private {
        
        RateLimit storage rl = rateLimits[from];
        
        uint256 currentTime = block.timestamp;
        uint256 currentBlock = block.number;

        if (checkTxInterval) {
            require(currentTime >= rl.lastTxTime + minTxInterval,
                "MTXToken: must wait 1 minute between transactions");
        }
        
        if (checkBlockTxLimit) {
            if (rl.lastTxBlock == currentBlock) {
                rl.blockTxCount += 1;
            } else {
                rl.blockTxCount = 1;
                rl.lastTxBlock = currentBlock;
            }
            
            require(rl.blockTxCount < maxTxsPerBlock,
                "MTXToken: exceeded transactions per block limit");
        }
        
        // Check transactions per window limit (if enabled)
        if (checkWindowTxLimit) {

            if (currentTime > rl.windowStart + windowSize) {
                rl.windowStart = currentTime;
                rl.txCount = 0;
            }

            rl.txCount += 1;
            require(rl.txCount <= maxTxsPerWindow,
                "MTXToken: exceeded transactions per window limit");
        }
        
        // Update last transaction time
        rl.lastTxTime = currentTime;
    }

    /**
     * @notice Override transfer to check blacklist and wallet limits
     */
    function _update(address from, address to, uint256 value) internal override {        
        if (restrictionsEnabled) {

            // Check if contract is paused
            require(!accessRestriction.paused(), "Pausable: paused");

            if(checkBlackList){
                require(!blacklisted[from], "MTXToken: sender is blacklisted");
                require(!blacklisted[to], "MTXToken: recipient is blacklisted");
            }

            if(from != address(0) && to != address(0)){
                
                if(!whitelisted[to]){
                    if (checkMaxWalletBalance) { // Not a mint operation
                        require(balanceOf(to) + value <= maxWalletBalance, "MTXToken: recipient would exceed maximum wallet balance");
                    }
                }

                if(!whitelisted[from]){

                    if(checkMaxTransfer){
                        require(value <= maxTransferAmount, "MTXToken: transfer amount exceeds maximum allowed");
                    }
                    
                    _checkRateLimit(from);                    
                }
            }
        }
        
        super._update(from, to, value);
    }
}