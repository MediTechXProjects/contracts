// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {
    ERC20Burnable
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IMTXToken} from "./IMTXToken.sol";
import {AccessRestriction} from "../accessRistriction/AccessRestriction.sol";

/**
 * @title MTXToken Base Contract
 * @notice MTXToken is an OFT-compliant ERC20 token with permit and burn functionality, and role-based access control.
 * Minting is only enabled in the constructor on the BSC network and is disabled on other networks.
 * Cross-chain mint and burn is supported via LayerZero OFT bridge.
 */
contract MTXToken is OFT, ERC20Burnable, ERC20Permit, IMTXToken {
    // Maximum supply of 1 billion tokens
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    // Access restriction contract
    AccessRestriction public accessRestriction;

    // Transfer limits (based on 1 billion total supply)
    uint256 public maxWalletBalance = 100_000_000 * 10 ** 18; // 10% of 1 billion (100 million tokens)
    uint256 public maxTransferAmount = 5_000_000 * 10 ** 18; // 0.5% of 1 billion (5 million tokens)
    uint256 public minTxInterval = 20 seconds;

    mapping(address => uint256) public lastTxTime;

    // Whitelist mapping - whitelisted addresses bypass all checks
    mapping(address => bool) public override whitelisted;

    // Rate limiting control flags
    bool public checkTxInterval = true;
    bool public checkMaxTransfer = true;
    bool public checkMaxWalletBalance = true;
    bool public restrictionsEnabled = true;

    /**
     * @notice Modifier to restrict access to manager role
     */
    modifier onlyManager() {
        if (
            !accessRestriction.hasRole(
                accessRestriction.MANAGER_ROLE(),
                _msgSender()
            )
        ) revert CallerNotManager();
        _;
    }

    /**
     * @notice Modifier to restrict access to admin role
     */
    modifier onlyAdmin() {
        if (
            !accessRestriction.hasRole(
                accessRestriction.ADMIN_ROLE(),
                _msgSender()
            )
        ) revert CallerNotAdmin();
        _;
    }

    constructor(
        address _lzEndpoint,
        address _owner,
        address _accessRestriction,
        address _treasury
    )
        OFT("MediTechX", "MTX", _lzEndpoint, _owner)
        Ownable(_owner)
        ERC20Permit("MediTechX")
    {
        if (_accessRestriction == address(0))
            revert InvalidAccessRestrictionAddress();
        if (_owner == address(0)) revert InvalidOwnerAddress();
        if (_lzEndpoint == address(0)) revert InvalidLayerZeroEndpointAddress();
        if (_treasury == address(0)) revert InvalidTreasuryAddress();

        accessRestriction = AccessRestriction(_accessRestriction);

        _mint(_treasury, MAX_SUPPLY);
    }

    /**
     * @notice Update the access restriction contract address
     * @param _accessRestriction The new access restriction contract address
     * @dev Only callable by admin role
     */
    function setAccessRestriction(
        address _accessRestriction
    ) external onlyAdmin {
        if (_accessRestriction == address(0))
            revert InvalidAccessRestrictionAddress();

        emit AccessRestrictionUpdated(
            address(accessRestriction),
            _accessRestriction
        );
        accessRestriction = AccessRestriction(_accessRestriction);
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
    function removeFromWhitelist(
        address account
    ) external override onlyManager {
        if (account == address(0)) revert InvalidAccountAddress();

        whitelisted[account] = false;
        emit Whitelisted(account, false);
    }

    /**
     * @notice Enable or disable transaction interval check
     * @param enabled True to enable interval check, false to disable
     */
    function setCheckTxInterval(bool enabled) external override onlyManager {
        checkTxInterval = enabled;
        emit CheckTxIntervalUpdated(enabled);
    }

    /**
     * @notice Enable or disable maximum transfer amount check
     * @param enabled True to enable max transfer check, false to disable
     */
    function setCheckMaxTransfer(bool enabled) external override onlyManager {
        checkMaxTransfer = enabled;
        emit CheckMaxTransferUpdated(enabled);
    }

    /**
     * @notice Enable or disable maximum wallet balance check
     * @param enabled True to enable max wallet balance check, false to disable
     */
    function setCheckMaxWalletBalance(
        bool enabled
    ) external override onlyManager {
        checkMaxWalletBalance = enabled;
        emit CheckMaxWalletBalanceUpdated(enabled);
    }

    /**
     * @notice Set transfer limits (wallet balance and transfer amount)
     * @param _maxWalletBalance Maximum wallet balance allowed
     * @param _maxTransferAmount Maximum transfer amount allowed
     */
    function setTransferLimits(
        uint256 _maxWalletBalance,
        uint256 _maxTransferAmount
    ) external override onlyManager {
        if (_maxWalletBalance == 0) revert MaxWalletBalanceMustBeGreaterThan0();
        if (_maxTransferAmount == 0)
            revert MaxTransferAmountMustBeGreaterThan0();

        if (_maxWalletBalance < 30_000_000 * 10 ** 18)
            revert MaxWalletBalanceMustBeGreaterThan30Million();

        if (_maxTransferAmount < 100_000 * 10 ** 18)
            revert MaxTransferAmountMustBeGreaterThan100Thousand();

        maxWalletBalance = _maxWalletBalance;
        maxTransferAmount = _maxTransferAmount;

        emit TransferLimitsUpdated(_maxWalletBalance, _maxTransferAmount);
    }

    /**
     * @notice Set min tx interval
     * @param _minTxInterval Minimum time between transactions in seconds
     */
    function setMinTxInterval(uint256 _minTxInterval) external onlyManager {
        if (_minTxInterval == 0) revert MinTxIntervalMustBeGreaterThan0();
        if (_minTxInterval > 5 minutes)
            revert MinTxIntervalMustBeLessThan5Minutes();

        minTxInterval = _minTxInterval;

        emit MinTxIntervalUpdated(_minTxInterval);
    }

    /**
     * @notice Permanently disable all restrictions (one-time only, admin only)
     * This function can only be called once and makes the token fully unrestricted
     */
    function disableRestrictions() external override onlyAdmin {
        if (!restrictionsEnabled) revert RestrictionsAlreadyDisabled();

        restrictionsEnabled = false;
        emit RestrictionsDisabled();
    }

    /**
     * @notice Override transfer to check wallet limits
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        if (restrictionsEnabled) {
            if (from != address(0) && to != address(0)) {
                if (!whitelisted[to]) {
                    if (checkMaxWalletBalance) {
                        if (balanceOf(to) + value > maxWalletBalance)
                            revert RecipientWouldExceedMaxWalletBalance({
                                attemptedBalance: balanceOf(to) + value,
                                maxAllowed: maxWalletBalance
                            });
                    }
                }

                if (!whitelisted[from]) {
                    if (checkMaxTransfer) {
                        if (value > maxTransferAmount)
                            revert TransferAmountExceedsMaximumAllowed({
                                attemptedAmount: value,
                                maxAllowed: maxTransferAmount
                            });
                    }

                    if (checkTxInterval) {
                        uint256 currentTime = block.timestamp;

                        if (currentTime < lastTxTime[from] + minTxInterval)
                            revert PleaseWaitAFewMinutesBeforeSendingAnotherTransaction({
                                nextAllowedTimeSeconds: lastTxTime[from] +
                                    minTxInterval -
                                    currentTime
                            });

                        lastTxTime[from] = currentTime;
                    }
                }
            }
        }

        super._update(from, to, value);
    }
}
