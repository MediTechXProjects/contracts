# MTX Token — Documentation

## 1️⃣ Overview

**MTXToken** is an ERC-20 compatible cross-chain token built on **LayerZero's OFT (Omnichain Fungible Token)** standard.  
It integrates **security and anti-abuse mechanisms**, including:

- **Fixed maximum supply** (1 billion tokens minted at deployment)
- **Wallet holding caps**
- **Transfer amount limits**
- **Transaction rate limiting** (minimum interval between transactions)
- **Whitelist system** (whitelisted addresses bypass all restrictions)
- **Configurable restrictions** (can be individually enabled/disabled or permanently disabled)

The token ensures secure, controlled, and predictable behavior across all supported chains while maintaining compliance with LayerZero’s OFT interoperability framework.

---

## 🔗 Key Dependencies

| Dependency            | Source          | Purpose                                                          |
| --------------------- | --------------- | ---------------------------------------------------------------- |
| **ERC20Burnable**     | OpenZeppelin    | Enables token holders to burn their tokens                       |
| **ERC20Permit**       | OpenZeppelin    | Allows gasless approvals (EIP-2612)                              |
| **Ownable**           | OpenZeppelin    | Provides ownership management for administrative control         |
| **OFT**               | LayerZero Labs  | Enables omnichain token transfer between EVM-compatible networks |
| **AccessRestriction** | Custom Contract | Manages roles, permissions, and global pause functionality       |

---

### 2️⃣ Role Summary

| Role             | Description          | Key Functions                                                                                                                                                           |
| ---------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ADMIN_ROLE**   | Global administrator | `setAccessRestriction()`, `disableRestrictions()`                                                                                                                       |
| **MANAGER_ROLE** | Operational manager  | `setTransferLimits()`, `setMinTxInterval()`, `addToWhitelist()`, `removeFromWhitelist()`, `setCheckTxInterval()`, `setCheckMaxTransfer()`, `setCheckMaxWalletBalance()` |
| **DEFAULT_USER** | Normal user          | Regular transfers and burns                                                                                                                                             |

---

## 3️⃣ Supply Model and Mint Logic

| **Parameter**          | **Description**                                                                                                                                                                                 |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MAX_SUPPLY**         | `1,000,000,000 MTX` — fixed total supply cap defined at deployment.                                                                                                                             |
| **Constructor Mint**   | All `MAX_SUPPLY` tokens are minted to the treasury address during contract deployment. This is a one-time operation that occurs only on the source chain (BSC).                                 |
| **No Ongoing Minting** | The contract does not have a `mint()` function. All tokens are minted at deployment, and no additional tokens can be created after deployment.                                                  |
| **Burn Functionality** | Tokens can be burned using `burn()` or `burnFrom()` functions (inherited from ERC20Burnable). Burned tokens are permanently removed from circulation.                                           |
| **\_update()**         | Central transfer hook (LayerZero OFT standard) that enforces transfer restrictions, wallet limits, and rate limiting. Does not enforce supply limits since all tokens are minted at deployment. |

### 🔍 Summary

- **One-time minting:** All tokens are minted to the treasury during contract deployment. No ongoing minting capability exists.
- **Fixed supply:** The total supply is fixed at `MAX_SUPPLY` and cannot be increased after deployment.
- **Burn capability:** Tokens can be permanently burned using the standard ERC20Burnable functions, reducing the circulating supply.
- **Cross-chain transfers:** Tokens can be transferred across chains via LayerZero OFT bridge, which burns tokens on the source chain and re-mints them on the destination chain.

---

## 4️⃣ Cross-Chain (OFT) Behavior

**MTXToken** inherits from **LayerZero’s OFT (Omnichain Fungible Token)** standard, enabling seamless token transfers between EVM-compatible blockchains.

### 🔗 Core Mechanics

- **Burn on Source:**  
  When a user sends tokens from Chain A → Chain B, the tokens are **burned** on Chain A.

- **Mint on Destination:**  
  The LayerZero OFT protocol triggers a **re-mint** of the same token amount on Chain B.  
  This process does **not** create new tokens — it simply restores already existing supply on the destination chain.

- **Source Chain Deployment:**  
  All tokens are minted to the treasury during contract deployment on the source chain (BSC).  
  Other chains cannot mint new tokens independently — they only reissue tokens that were previously minted and burned via the OFT bridge.

- **Fixed Supply:**  
  The total supply is fixed at `MAX_SUPPLY` and minted at deployment. Cross-chain transfers redistribute existing supply but do not create new tokens.

### 🔥 Burn & Transfer Mechanics

| Action                           | Supply Impact                     | Notes                                              |
| -------------------------------- | --------------------------------- | -------------------------------------------------- |
| Constructor mint (deployment)    | All MAX_SUPPLY minted to treasury | One-time operation on source chain only            |
| Local burn (`burn` / `burnFrom`) | Permanently reduces supply        | Tokens are permanently removed from circulation    |
| Bridge burn (Chain A → B)        | Supply unchanged                  | Tokens burned on source, re-minted on destination  |
| Bridge re-mint (Chain B)         | Supply unchanged                  | Reissues existing supply on destination chain only |

---

# 5️⃣ \_update Function Details (Critical Section)

This section explains the `_update` function in the MTXToken contract, which is the **central point for all token transfers**, including rate limiting, wallet limits, and whitelist checks.

The function performs the following checks (in order):

1. **Restrictions Enabled Check** - Only applies restrictions if `restrictionsEnabled` is true
2. **Wallet Balance Limits** - Enforces maximum wallet balance for non-whitelisted recipients
3. **Transfer Amount Limits** - Enforces maximum transfer amount for non-whitelisted senders
4. **Transaction Interval Limits** - Enforces minimum time between transactions for non-whitelisted senders

## 1️⃣ Restrictions Enabled Check

```solidity
if (restrictionsEnabled) {
    // Apply all restriction checks
}
```

- All restriction checks are only applied when `restrictionsEnabled` is `true`.
- When `restrictionsEnabled` is `false`, all restrictions are bypassed and the token operates without limits.
- The `disableRestrictions()` function (admin-only, one-time) permanently sets this to `false`.

## 2️⃣ Wallet Balance Limits

```solidity
if(!whitelisted[to]){
    if (checkMaxWalletBalance) {
        if (balanceOf(to) + value > maxWalletBalance) revert RecipientWouldExceedMaxWalletBalance();
    }
}
```

- **Applies to:** Normal transfers (when both `from` and `to` are non-zero addresses)
- **Recipient check:** If the recipient is not whitelisted and `checkMaxWalletBalance` is enabled, the recipient's balance after the transfer cannot exceed `maxWalletBalance`.
- **Default value:** `maxWalletBalance = 100,000,000 MTX` (10% of MAX_SUPPLY)
- **Whitelist bypass:** Whitelisted addresses are exempt from this check.

## 3️⃣ Transfer Amount Limits

```solidity
if(!whitelisted[from]){
    if(checkMaxTransfer){
        if (value > maxTransferAmount) revert TransferAmountExceedsMaximumAllowed();
    }
}
```

- **Applies to:** Normal transfers (when both `from` and `to` are non-zero addresses)
- **Sender check:** If the sender is not whitelisted and `checkMaxTransfer` is enabled, the transfer amount cannot exceed `maxTransferAmount`.
- **Default value:** `maxTransferAmount = 5,000,000 MTX` (0.5% of MAX_SUPPLY)
- **Whitelist bypass:** Whitelisted addresses are exempt from this check.

## 4️⃣ Transaction Interval Limits

```solidity
if(!whitelisted[from]){
    if (checkTxInterval) {
        uint256 currentTime = block.timestamp;
        if (currentTime < lastTxTime[from] + minTxInterval) revert PleaseWaitAFewMinutesBeforeSendingAnotherTransaction();
        lastTxTime[from] = currentTime;
    }
}
```

- **Applies to:** Normal transfers (when both `from` and `to` are non-zero addresses)
- **Rate limiting:** If the sender is not whitelisted and `checkTxInterval` is enabled, there must be at least `minTxInterval` seconds between consecutive transactions from the same address.
- **Default value:** `minTxInterval = 30 seconds`
- **Maximum value:** Cannot exceed 5 minutes
- **Whitelist bypass:** Whitelisted addresses are exempt from this check.

## 5️⃣ Whitelist System

- **Whitelisted addresses** bypass all restriction checks:
  - No wallet balance limits
  - No transfer amount limits
  - No transaction interval limits
- **Management:** Only addresses with `MANAGER_ROLE` can add or remove addresses from the whitelist via `addToWhitelist()` and `removeFromWhitelist()` functions.
- **Note:** The contract does not have a blacklist feature. Only whitelist is supported.

## 6️⃣ Configuration Functions

All restriction checks can be individually enabled or disabled by addresses with `MANAGER_ROLE`:

- `setCheckMaxWalletBalance(bool enabled)` - Enable/disable wallet balance checks
- `setCheckMaxTransfer(bool enabled)` - Enable/disable transfer amount checks
- `setCheckTxInterval(bool enabled)` - Enable/disable transaction interval checks
- `setTransferLimits(uint256 _maxWalletBalance, uint256 _maxTransferAmount)` - Update wallet and transfer limits
- `setMinTxInterval(uint256 _minTxInterval)` - Update minimum transaction interval
