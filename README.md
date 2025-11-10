# MTX Token — Documentation

## 1️⃣ Overview

**MTXToken** is an ERC-20 compatible cross-chain token built on **LayerZero’s OFT (Omnichain Fungible Token)** standard.  
It integrates **security and anti-abuse mechanisms**, including:

- **Maximum mint supply limit**
- **Wallet holding caps**
- **Transfer and rate limiting**
- **Blacklist / Whitelist enforcement**
- **Global pause control via AccessRestriction**

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

| Role              | Description                   | Key Functions                                                        |
| ----------------- | ----------------------------- | -------------------------------------------------------------------- |
| **ADMIN_ROLE**    | Global administrator          | `setAccessRestriction()`, `disableRestrictions()`                    |
| **MANAGER_ROLE**  | Operational manager           | `setTransferLimits()`, `setRateLimitingParams()`, `addToBlacklist()` |
| **TREASURY_ROLE** | Token issuer (mint authority) | `mint()`                                                             |
| **DEFAULT_USER**  | Normal user                   | Regular transfers and burns                                          |

---

## 3️⃣ Supply Model and Mint Logic

| **Parameter**   | **Description**                                                                                                                                                                                                             |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MAX_SUPPLY**  | `1,000,000,000 MTX` — fixed total supply cap defined at deployment.                                                                                                                                                         |
| **totalMinted** | Tracks all tokens minted by the Treasury on the source chain via the `mint()` function. This value **never decreases**, even if tokens are burned or bridged.                                                               |
| **totalBurned** | Tracks all tokens burned locally via `burn()` or `burnFrom()` functions. This value **never decreases** and effectively reduces the maximum mintable supply to `MAX_SUPPLY - totalBurned`.                                  |
| **mint()**      | Callable **only by `TREASURY_ROLE`**. Used to issue new tokens. Checks: `if (totalMinted + amount > MAX_SUPPLY)`.                                                                                                           |
| **\_update()**  | Central transfer hook (LayerZero OFT standard) that ensures **all minting operations** (Treasury mints and bridge re-issuances) cannot exceed `MAX_SUPPLY - totalBurned`. This prevents burned tokens from being re-minted. |

### 🔍 Summary

- **Treasury-controlled minting:** All new token issuance occurs exclusively through the Treasury wallet.
- **Burn tracking:** When tokens are burned, `totalBurned` increases, reducing the effective maximum supply. This ensures burned tokens cannot be re-minted.
- **Cross-chain safety:** The `_update()` function enforces that all mint operations (including bridge re-issuances) respect the `MAX_SUPPLY - totalBurned` limit.
- **Fixed-cap design:** Even with burns or bridge transfers, total token circulation across all chains remains ≤ `MAX_SUPPLY - totalBurned`.

---

## 4️⃣ Cross-Chain (OFT) Behavior

**MTXToken** inherits from **LayerZero’s OFT (Omnichain Fungible Token)** standard, enabling seamless token transfers between EVM-compatible blockchains.

### 🔗 Core Mechanics

- **Burn on Source:**  
  When a user sends tokens from Chain A → Chain B, the tokens are **burned** on Chain A.

- **Mint on Destination:**  
  The LayerZero OFT protocol triggers a **re-mint** of the same token amount on Chain B.  
  This process does **not** count as new minting — it simply restores already existing supply on the destination chain.

- **Source Chain Treasury Mint Only:**  
  The **Treasury** is the **only entity allowed to perform actual minting**, and this can **only occur on the Source Chain**.  
  Other chains cannot mint new tokens independently — they only reissue tokens that were previously minted and burned via the OFT bridge.

- **Supply Enforcement:**  
  The `_update()` function ensures that the **aggregate token supply across all chains** never exceeds `MAX_SUPPLY - totalBurned`. This accounts for tokens burned locally, preventing them from being re-minted.

- **Mint Path Limitation:**  
  All mint operations (Treasury mints and bridge re-issuances) are **strictly limited by `MAX_SUPPLY - totalBurned`**, ensuring that burned tokens cannot be re-minted and maintaining supply integrity across all chains.

### 🔥 Burn & Mint Mechanics

| Action                           | `totalMinted` | `totalBurned` | Effective MAX_SUPPLY (`MAX_SUPPLY - totalBurned`) | Notes                                                               |
| -------------------------------- | ------------- | ------------- | ------------------------------------------------- | ------------------------------------------------------------------- |
| Treasury mint                    | ↑             | -             | MAX_SUPPLY - totalBurned                          | Minting new tokens on source chain only, limited by MAX_SUPPLY      |
| Local burn (`burn` / `burnFrom`) | -             | ↑             | MAX_SUPPLY - totalBurned                          | Reduces effective supply, tokens cannot be re-minted                |
| Bridge burn (Chain A → B)        | -             | -             | MAX_SUPPLY - totalBurned                          | Tokens burned on source, re-minted on destination, supply unchanged |
| Bridge re-mint (Chain B)         | -             | -             | MAX_SUPPLY - totalBurned                          | Reissues existing supply on destination chain only                  |

---

# 5️⃣ \_update Function Details (Critical Section)

This section explains the `_update` function in the MTXToken contract, which is the **central point for all token transfers, minting, and burning**, including rate limiting, wallet limits, and whitelist/blacklist checks.

1-Enforce maximum mint supply (MAX_SUPPLY)

2-Control minting paths and roles

3-Apply rate limiting on transactions

4-Apply wallet and transfer limits

5-Enforce whitelist / blacklist rules

6-Respect paused state of the contract

## 2️⃣ Mint Path Check

```solidity
if(from == address(0)) {
    if (totalSupply() + value > MAX_SUPPLY - totalBurned) revert MintingWouldExceedMaxSupply();
}
```

- When `from == address(0)`, a **mint operation** is occurring.
- The contract enforces that the total supply after minting cannot exceed `MAX_SUPPLY - totalBurned`.
- **`totalBurned`** tracks all tokens burned locally via `burn()` or `burnFrom()` functions. This value **never decreases** and effectively reduces the maximum mintable supply.
- **Note:** This check applies to **all mint operations**, including:
  - Treasury mints (via `mint()` function)
  - Bridge re-issuances (cross-chain token transfers)
- **Note:** When tokens are burned, `totalBurned` increases, which reduces the effective maximum supply (`MAX_SUPPLY - totalBurned`). This ensures that burned tokens cannot be re-minted, maintaining supply integrity.
- **Note:** The `mint()` function has an additional check: `if (totalMinted + amount > MAX_SUPPLY)`, which prevents Treasury from minting more than `MAX_SUPPLY` regardless of burns.

## 3️⃣ Source Chain Clarification

- **Direct minting is only allowed on the Source Chain.** No tokens can be minted directly on destination chains.
- Tokens transferred via the OFT bridge from other chains are **reissued logically** on the destination chain; this process does **not** increase `totalMinted` or `totalBurned`.
- The `_update()` function enforces that **all mint operations** (including bridge re-issuances) respect the `MAX_SUPPLY - totalBurned` limit, ensuring supply integrity across all chains.
- When tokens are burned on any chain, the effective maximum supply is reduced, preventing those tokens from being re-minted anywhere.

## 4️⃣ Restrictions Enabled Check

```solidity
if (restrictionsEnabled) {
    if (accessRestriction.paused()) revert Paused();
```

- Ensures no transactions occur if the contract is **paused**.

## 5️⃣ Blacklist Enforcement

```solidity
if(checkBlackList){
    if (blacklisted[from]) revert SenderIsBlacklisted();
    if (blacklisted[to]) revert RecipientIsBlacklisted();
}
```

- Prevents blacklisted addresses from sending or receiving tokens.

## 6️⃣ Wallet & Transfer Limits

```solidity
if(from != address(0) && to != address(0)){
    if(!whitelisted[to] && checkMaxWalletBalance){
        if (balanceOf(to) + value > maxWalletBalance) revert RecipientWouldExceedMaxWalletBalance();
    }

    if(!whitelisted[from]){
        if(checkMaxTransfer && value > maxTransferAmount) revert TransferAmountExceedsMaximumAllowed();
        _checkRateLimit(from, value);
    }
}
```

- These checks **only apply to normal transfers**, not mint operations.
- **Recipient wallet limit:** enforced if the recipient is not whitelisted.
- **Sender transfer limit:** enforced if the sender is not whitelisted.
- **Rate limiting:** ensures users cannot spam transactions, including:
  - Maximum transactions per block
  - Maximum transactions per time window
  - Minimum interval between consecutive transactions
