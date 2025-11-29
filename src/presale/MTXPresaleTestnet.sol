// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MTXPresale.sol";

contract MTXPresaleTestnet is MTXPresale {

    uint256 public constant TEST_MONTH = 6 hours;

    constructor(
        address _mtxToken,
        address _accessRestriction,
        address _priceFeed,
        uint256 _start,
        uint256 _end,
        uint256 _listing,
        uint256 _p1,
        uint256 _p2,
        uint256 _p3
    )
        MTXPresale(
            _mtxToken,
            _accessRestriction,
            _priceFeed,
            _start,
            _end,
            _listing,
            _p1,
            _p2,
            _p3
        )
    {}

    function calculateClaimable(Purchase memory purchase)
        public
        view
        override
        returns (uint256)
    {

        uint256 remaining = purchase.mtxAmount - purchase.claimedAmount;

        if (remaining == 0) return 0;

        uint256 currentTime = block.timestamp;

        if (purchase.model == LockModelType.SIX_MONTH_LOCK) {
            // Model 1: All tokens unlock after 6 months from listing time
            uint256 unlockTime = listingTime + (6 * TEST_MONTH);
            if (currentTime >= unlockTime) {
                return remaining;
            }
        } else if (purchase.model == LockModelType.HALF_3M_HALF_6M) {
            // Model 2: 50% at 3 months, 50% at 6 months (from listing time)
            uint256 threeMonths = listingTime + (3 * TEST_MONTH);
            uint256 sixMonths = listingTime + (6 * TEST_MONTH);

            uint256 firstHalf = purchase.mtxAmount / 2;

            if (currentTime >= sixMonths) {
                return remaining; // All unlocked
            } else if (currentTime >= threeMonths) {
                if (purchase.claimedAmount < firstHalf) {
                    return firstHalf - purchase.claimedAmount;
                }
            }
        } else if (purchase.model == LockModelType.MONTHLY_VESTING) {

            if (currentTime < listingTime) return 0;

            uint256 totalUnlocked = 0;

            uint256 amount20 = (purchase.mtxAmount * 20) / 100;
            uint256 amount16 = (purchase.mtxAmount * 16) / 100;

            // --------- Phase 1: At listing time (20%) ---------
            totalUnlocked += amount20;

            // --------- Phase 2: After 35 days (16%) ----------
            uint256 t35 = listingTime + TEST_MONTH + 1 hours;

            if (currentTime >= t35) {
                totalUnlocked += amount16;
            }

            uint256 baseTime = t35;

            if (currentTime >= baseTime) {
                uint256 monthsPassed = (currentTime - baseTime) / TEST_MONTH;

                if (monthsPassed > 4) monthsPassed = 4;

                totalUnlocked += monthsPassed * amount16;
            }

            if (totalUnlocked > purchase.mtxAmount) {
                totalUnlocked = purchase.mtxAmount;
            }

            if (totalUnlocked > purchase.claimedAmount) {
                return totalUnlocked - purchase.claimedAmount;
            }
        }

        return 0;

    }
}
