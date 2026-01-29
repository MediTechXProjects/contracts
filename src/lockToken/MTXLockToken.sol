// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessRestriction } from "../accessRistriction/AccessRestriction.sol";
import { IMTXLockToken } from "./IMTXLockToken.sol";



contract MTXLockToken is IMTXLockToken, ReentrancyGuard {


    IERC20 public immutable mtxToken;
    AccessRestriction public immutable accessRestriction;

    mapping(address => LockToken[]) public userLockTokens;
    mapping(address => uint256) public userTotalLocked;
    
    uint256 public totalLocked;
    uint256 public totalClaimed;

    modifier onlyAdmin() {
        require(accessRestriction.hasRole(accessRestriction.ADMIN_ROLE(), msg.sender), "Caller not admin");
        _;
    }

    modifier onlyManager() {
        require(accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), msg.sender), "Caller not manager");
        _;
    }

    constructor(
        address _mtxToken,
        address _accessRestriction
    ) {
        require(_mtxToken != address(0), "Invalid address");
        require(_accessRestriction != address(0), "Invalid address");

        mtxToken = IERC20(_mtxToken);
        accessRestriction = AccessRestriction(_accessRestriction);
    }

    function lock(address user, uint256 amount, uint256 unlockTime)
        external
        override
        onlyAdmin
    {
        require(amount > 0, "Invalid amount");
        require(unlockTime > block.timestamp, "Invalid unlock time");
                
        userTotalLocked[user] += amount;
        totalLocked += amount;

        userLockTokens[user].push(LockToken({
            amount: amount,
            unlockTime: unlockTime,
            claimed: false
        }));

        emit TokenLocked(user, amount, unlockTime);
    }

    function claimWithManager(uint256 from, uint256 to, address user) external override nonReentrant onlyManager {
        _claim(from,to,user);
    }

    function claim(uint256 from, uint256 to) external override nonReentrant {
        _claim(from,to,msg.sender);
    }

    /**
     * @notice Withdraw remaining MTX tokens (admin only)
     * @param to Address to send MTX tokens to
     */
    function withdraw(address to) external override onlyAdmin {
        require(to != address(0), "Invalid address");

        uint256 balance = mtxToken.balanceOf(address(this));

        uint256 totalUnClaimed = totalLocked - totalClaimed;

        require(balance > totalUnClaimed, "Invalid amount");

        uint256 withdrawableAmount = balance - totalUnClaimed;

        require(withdrawableAmount > 0, "Invalid amount");

        bool success = mtxToken.transfer(to, withdrawableAmount);

        require(success, "Transfer failed");

        emit MTXTokensWithdrawn(to, withdrawableAmount);
    }

    function _claim(uint256 from, uint256 to, address user) private {
        LockToken[] storage lockTokens = userLockTokens[user];

        require(lockTokens.length > 0, "No tokens to claim");
        require(from < to || to == 0, "Invalid range");

        if (to == 0 || to > lockTokens.length) {
            to = lockTokens.length;
        }

        uint256 totalClaimable;

        for (uint256 i = from; i < to; i++) {

            LockToken storage l = lockTokens[i];

            if (l.claimed) continue;
            if (block.timestamp < l.unlockTime) continue;

            l.claimed = true;
            totalClaimable += l.amount;

            emit TokenClaimed(user, l.amount, i);
        }

        totalClaimed += totalClaimable;
    
        require(totalClaimable > 0, "No tokens to claim");

        bool success = mtxToken.transfer(user, totalClaimable);
        
        require(success, "Transfer failed");
    }
}
