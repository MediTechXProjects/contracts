// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IMEXToken
 * @notice Interface for MEXToken contract
 */
interface IMEXToken is IERC20 {


    error CallerNotManager();
    error CallerNotAdmin();
    error MaxWalletBalanceMustBeGreaterThan0();
    error MaxTransferAmountMustBeGreaterThan0();
    error RestrictionsAlreadyDisabled();
    error RecipientWouldExceedMaxWalletBalance(uint256 attemptedBalance, uint256 maxAllowed);
    error TransferAmountExceedsMaximumAllowed(uint256 attemptedAmount, uint256 maxAllowed);
    error PleaseWaitAFewMinutesBeforeSendingAnotherTransaction(uint256 nextAllowedTimeSeconds);

    error InvalidAccessRestrictionAddress();
    error InvalidOwnerAddress();
    error InvalidLayerZeroEndpointAddress();
    error InvalidAccountAddress();
    error InvalidTreasuryAddress();
    error MinTxIntervalMustBeGreaterThan0();
    error MinTxIntervalMustBeLessThan5Minutes();
    error MaxWalletBalanceMustBeGreaterThan30Million();
    error MaxTransferAmountMustBeGreaterThan100Thousand();

    
    event Whitelisted(address indexed account, bool isWhitelisted);
    event RestrictionsDisabled();
    event TransferLimitsUpdated(uint256 maxWalletBalance, uint256 maxTransferAmount);
    event AccessRestrictionUpdated(address oldContract, address newContract);
    event CheckTxIntervalUpdated(bool enabled);
    event CheckMaxTransferUpdated(bool enabled);
    event CheckMaxWalletBalanceUpdated(bool enabled);
    event MinTxIntervalUpdated(uint256 minTxInterval);
    
    function whitelisted(address account) external view returns (bool);
    
    function addToWhitelist(address account) external;
    function removeFromWhitelist(address account) external;
    
    function disableRestrictions() external;
    
    function setCheckTxInterval(bool enabled) external;
    function setCheckMaxTransfer(bool enabled) external;
    function setCheckMaxWalletBalance(bool enabled) external;
    function setTransferLimits(uint256 _maxWalletBalance, uint256 _maxTransferAmount) external;
    function setMinTxInterval(uint256 _minTxInterval) external;
}
