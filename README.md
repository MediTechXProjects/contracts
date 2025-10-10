# MTXToken `_update` Function

This section explains the `_update` function in the MTXToken contract, which is the **central point for all token transfers, minting, and burning**, including rate limiting, wallet limits, and whitelist/blacklist checks.

---

## `_update` Function Code

```solidity
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
                if (checkMaxWalletBalance) {
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
