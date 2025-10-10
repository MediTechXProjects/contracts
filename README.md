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


## 3️⃣ Restrictions Enabled Check

```solidity
if (restrictionsEnabled) {
    if (accessRestriction.paused()) revert Paused();
```
- Ensures no transactions occur if the contract is **paused**.

## 4️⃣ Blacklist Enforcement

```solidity
if(checkBlackList){
    if (blacklisted[from]) revert SenderIsBlacklisted();
    if (blacklisted[to]) revert RecipientIsBlacklisted();
}
```
- Prevents blacklisted addresses from sending or receiving tokens.

## 5️⃣ Wallet & Transfer Limits

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

  ### 7️⃣ Source Chain Clarification

- **Important:** Direct minting is **only allowed on the Source Chain**.
- Destination chains (other bridges) **do not mint directly**.
- Tokens arriving from other chains via the OFT bridge are **reissued logically** without modifying `totalMinted`.
- This design ensures that `MAX_SUPPLY` and `totalMinted` limits apply **only to tokens physically minted on the Source Chain**.  
  Tokens transferred between chains are exempt from this restriction.


