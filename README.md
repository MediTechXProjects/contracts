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
