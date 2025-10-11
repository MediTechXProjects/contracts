# 🧩 MTX Token — Audit Documentation

## 1️⃣ Overview

**MTXToken** is an ERC-20 compatible cross-chain token built on **LayerZero’s OFT (Omnichain Fungible Token)** standard.  
It integrates advanced **security and anti-abuse mechanisms**, including:

- **Maximum mint supply limit**
- **Wallet holding caps**
- **Transfer and rate limiting**
- **Blacklist / Whitelist enforcement**
- **Global pause control via AccessRestriction**

The token ensures secure, controlled, and predictable behavior across all supported chains while maintaining compliance with LayerZero’s OFT interoperability framework.

---

## 🔗 Key Dependencies

| Dependency | Source | Purpose |
|-------------|---------|----------|
| **ERC20Burnable** | OpenZeppelin | Enables token holders to burn their tokens |
| **ERC20Permit** | OpenZeppelin | Allows gasless approvals (EIP-2612) |
| **Ownable** | OpenZeppelin | Provides ownership management for administrative control |
| **OFT** | LayerZero Labs | Enables omnichain token transfer between EVM-compatible networks |
| **AccessRestriction** | Custom Contract | Manages roles, permissions, and global pause functionality |

---


# MTXToken `_update` Function

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
    bool isTreasury = accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), _msgSender());
    uint256 limit = isTreasury ? MAX_SUPPLY : totalMinted;
    if (totalSupply() + value > limit) revert MintingWouldExceedMaxSupply();
}
```

- When `from == address(0)`, a **mint operation** is occurring.
- The contract checks if the caller has the **Treasury role**:
  - **Treasury mint:** allowed up to `MAX_SUPPLY` (new tokens issued by admin/treasury)
  - **Other mint paths** (e.g., bridge): allowed only up to `totalMinted`, preventing excessive issuance
- **Note:** `totalMinted` is only incremented inside the `mint()` function. Other mint paths, such as bridge re-issuances, **do not increase `totalMinted`**.
- **Note:** Bridge reissuances do not increment totalMinted, so _update ensures that the bridge cannot mint more than what was originally minted by Treasury.
- **Note:** This mechanism enforces the maximum supply constraint on tokens minted on the Source Chain while allowing safe cross-chain transfers.

## 3️⃣ Source Chain Clarification

- **Direct minting is only allowed on the Source Chain.** No tokens can be minted directly on destination chains.
- Tokens transferred via the OFT bridge from other chains are **reissued logically** on the destination chain; this process does **not** increase `totalMinted`.
- As a result, `MAX_SUPPLY` and `totalMinted` limits apply **only to tokens minted on the Source Chain**.
- Tokens moving between chains through the bridge are **exempt from these minting limits**, ensuring cross-chain transfers do not violate supply constraints.


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

