// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IMTXLockToken
 * @notice Interface for MTXLockToken contract
 */
interface IMTXLockToken {

    struct LockToken {
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
    }

    event TokenLocked(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed unlockTime
    );
    event TokenClaimed(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed index
    );
    event MTXTokensWithdrawn(address indexed to, uint256 amount);



    function lock(address user, uint256 amount, uint256 unlockTime) external;
    function claim(uint256 from, uint256 to) external;
    function claimWithManager(uint256 from, uint256 to, address user) external;
    function withdraw(address to) external;
}
