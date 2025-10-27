// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IMTXToken } from "./IMTXToken.sol";
import { AccessRestriction } from "../accessRistriction/AccessRestriction.sol";

/**
 * @title MTXToken (Source Chain Deployment)
 * @notice This contract is deployed on the Source Network (BSC).
 * Only the Source deployment contains the `mint` function,
 * allowing the Treasury to mint new tokens up to the MAX_SUPPLY limit.
 *
 * Other chain deployments (destination chains) do not include the mint function
 * and only support cross-chain re-minting through the LayerZero OFT bridge.
 */
contract MTXToken is OFT, ERC20Burnable, ERC20Permit, IMTXToken {

    // Maximum supply of 1 billion tokens
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    // Access restriction contract
    AccessRestriction public accessRestriction;
    
    // totalMinted never decreases to ensure MAX_SUPPLY tracking.
    // Burned tokens are excluded from totalSupply() only.
    uint256 public totalMinted;
    
    // Transfer limits (based on 1 billion total supply)
    uint256 public maxWalletBalance = 100_000_000 * 10**18; // 10% of 1 billion (100 million tokens)
    uint256 public maxTransferAmount = 5_000_000 * 10**18;  // 0.5% of 1 billion (5 million tokens)


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
    bool public restrictionsEnabled = true;
    
    
    // Rate limiting parameters
    uint32  public maxTxsPerWindow = 3;
    uint32  public maxTxsPerBlock = 1;
    uint64  public windowSize = 15 minutes;
    uint64  public minTxInterval = 1 minutes;
    uint256 public maxAmountPerWindow = 100_000_000 * 10**18;
    
    // Rate limiting state
    struct RateLimit {
        uint256 windowAmount;
        uint64 windowStart;
        uint64 lastTxTime;
        uint64 lastTxBlock;
        uint32 blockTxCount;
        uint32 txCount;
    }
    
    mapping(address => RateLimit) private rateLimits;
    
    /**
     * @notice Modifier to restrict access to manager role
     */
    modifier onlyManager() {
        if (!accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), _msgSender())) revert CallerNotManager();
        _;
    }

    /**
     * @notice Modifier to restrict access to admin role
     */
    modifier onlyAdmin() {
        if (!accessRestriction.hasRole(accessRestriction.ADMIN_ROLE(), _msgSender())) revert CallerNotAdmin();
        _;
    }

    /**
     * @notice Modifier to restrict access to treasury role
     */
    modifier onlyTreasury() {
        if (!accessRestriction.hasRole(accessRestriction.TREASURY_ROLE(), _msgSender())) revert CallerNotTreasury();
        _;
    }

    constructor(
        address _lzEndpoint,
        address _owner,
        address _accessRestriction
    ) OFT("mtx-token","MTX", _lzEndpoint, _owner) Ownable(_owner) ERC20Permit("mtx-token") {

        if (_accessRestriction == address(0)) revert InvalidAccessRestrictionAddress();
        if (_owner == address(0)) revert InvalidOwnerAddress();
        if (_lzEndpoint == address(0)) revert InvalidLayerZeroEndpointAddress();

        accessRestriction = AccessRestriction(_accessRestriction);
    }

    /**
     * @notice Mint tokens to a specified address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyTreasury {
        if (totalMinted + amount > MAX_SUPPLY) revert MintingWouldExceedMaxSupply();

        totalMinted += amount;
        _mint(to, amount);
    }

    
    /**
     * @notice Update the access restriction contract address
     * @param _accessRestriction The new access restriction contract address
     * @dev Only callable by manager role
     */
    function setAccessRestriction(address _accessRestriction) external onlyAdmin {
        
        if (_accessRestriction == address(0)) revert InvalidAccessRestrictionAddress();

        emit AccessRestrictionUpdated(address(accessRestriction), _accessRestriction);
        accessRestriction = AccessRestriction(_accessRestriction);
    }


    /**
     * @notice Add an address to the blacklist
     * @param account The address to blacklist
     */
    function addToBlacklist(address account) external override onlyManager {

        if (account == address(0)) revert InvalidAccountAddress();

        blacklisted[account] = true;
        emit Blacklisted(account, true);
    }

    /**
     * @notice Remove an address from the blacklist
     * @param account The address to remove from blacklist
     */
    function removeFromBlacklist(address account) external override onlyManager {
        
        if (account == address(0)) revert InvalidAccountAddress();

        blacklisted[account] = false;
        emit Blacklisted(account, false);
    }

    /**
     * @notice Add an address to the whitelist
     * @param account The address to whitelist
     */
    function addToWhitelist(address account) external override onlyManager {
        
        if (account == address(0)) revert InvalidAccountAddress();

        whitelisted[account] = true;
        emit Whitelisted(account, true);
    }

    /**
     * @notice Remove an address from the whitelist
     * @param account The address to remove from whitelist
     */
    function removeFromWhitelist(address account) external override onlyManager {

        if (account == address(0)) revert InvalidAccountAddress();

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

        if (_maxWalletBalance == 0) revert MaxWalletBalanceMustBeGreaterThan0();
        if (_maxTransferAmount == 0) revert MaxTransferAmountMustBeGreaterThan0();
        
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
        uint32 _maxTxsPerWindow,
        uint64 _windowSize,
        uint64 _minTxInterval,
        uint32 _maxTxsPerBlock,
        uint256 _maxAmountPerWindow
    ) external onlyManager {


        if (_maxTxsPerWindow == 0) revert MaxTxsPerWindowMustBeGreaterThan0();
        if (_windowSize == 0) revert WindowSizeMustBeGreaterThan0();
        if (_minTxInterval == 0) revert MinTxIntervalMustBeGreaterThan0();
        if (_maxTxsPerBlock == 0) revert MaxTxsPerBlockMustBeGreaterThan0();
        if (_maxAmountPerWindow == 0) revert MaxAmountPerWindowMustBeGreaterThan0();

        maxTxsPerWindow = _maxTxsPerWindow;
        windowSize = _windowSize;
        minTxInterval = _minTxInterval;
        maxTxsPerBlock = _maxTxsPerBlock;
        maxAmountPerWindow = _maxAmountPerWindow;
        
        emit RateLimitingParamsUpdated(_maxTxsPerWindow, _windowSize, _minTxInterval, _maxTxsPerBlock, _maxAmountPerWindow);
    }

    /**
     * @notice Permanently disable all restrictions (one-time only, admin only)
     * This function can only be called once and makes the token fully unrestricted
     */
    function disableRestrictions() override external onlyAdmin {

        if (!restrictionsEnabled) revert RestrictionsAlreadyDisabled();
        
        restrictionsEnabled = false;
        emit RestrictionsDisabled();
    }

    /**
     * @notice Private function to check and update rate limits for an address
     * @param from The address to check rate limits for
     */
    function _checkRateLimit(address from, uint256 amount) private {
        
        RateLimit storage rl = rateLimits[from];
        
        uint64 currentTime = uint64(block.timestamp);
        uint64 currentBlock = uint64(block.number);

        if (checkTxInterval) {
            if (currentTime < rl.lastTxTime + minTxInterval) revert TooManyTransactions();
        }
        
        if (checkBlockTxLimit) {
            if (rl.lastTxBlock == currentBlock) {
                rl.blockTxCount += 1;
            } else {
                rl.blockTxCount = 1;
                rl.lastTxBlock = currentBlock;
            }
            
            if (rl.blockTxCount > maxTxsPerBlock) revert ExceededTransactionsPerBlockLimit();
        }
        
        // Check transactions per window limit (if enabled)
        if (checkWindowTxLimit) {

            if (currentTime >= rl.windowStart + windowSize) {
                rl.windowStart = currentTime;
                rl.txCount = 0;
                rl.windowAmount = 0;
            }

            rl.txCount += 1;
            rl.windowAmount += amount;
            if (rl.txCount > maxTxsPerWindow) revert ExceededTransactionsPerWindowLimit();
            if (rl.windowAmount > maxAmountPerWindow) revert ExceededAmountPerWindowLimit();
        }
        
        // Update last transaction time
        rl.lastTxTime = currentTime;
    }

    /**
     * @notice Override transfer to check blacklist and wallet limits
     */
    function _update(address from, address to, uint256 value) internal override {

        if(from == address(0)) {
            bool isTreasury = accessRestriction.hasRole(accessRestriction.TREASURY_ROLE(), _msgSender());
            uint256 limit = isTreasury ? MAX_SUPPLY : totalMinted;
            if (totalSupply() + value > limit) revert MintingWouldExceedMaxSupply();
        }

        if (restrictionsEnabled) {

            // Check if contract is paused
            if (accessRestriction.paused()) revert Paused();

            if(checkBlackList){
                if (blacklisted[from]) revert SenderIsBlacklisted();
                if (blacklisted[to]) revert RecipientIsBlacklisted();
            }

            if(from != address(0) && to != address(0)){
                
                if(!whitelisted[to]){
                    if (checkMaxWalletBalance) { // Not a mint operation
                        if (balanceOf(to) + value > maxWalletBalance) revert RecipientWouldExceedMaxWalletBalance();
                    }
                }

                if(!whitelisted[from]){

                    if(checkMaxTransfer){
                        if (value > maxTransferAmount) revert TransferAmountExceedsMaximumAllowed();
                    }
                    
                    _checkRateLimit(from, value);                    
                }
            }
        }
        
        super._update(from, to, value);
    }
}