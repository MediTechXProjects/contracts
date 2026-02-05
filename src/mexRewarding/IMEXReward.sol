// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IMEXReward
 * @notice Interface for MEXReward contract
 */
interface IMEXReward {
    /**
     * @notice Struct representing a reward authorization
     * @param user   Address eligible to claim the reward
     * @param amount Amount of tokens to be rewarded
     * @param nonce  User-specific nonce to prevent replay
     */
    struct Reward {
        address user;
        uint256 amount;
        uint256 nonce;
    }

    /**
     * @notice Emitted when a reward is successfully claimed
     * @param user   The address that claimed the reward
     * @param amount The amount of tokens claimed
     * @param nonce  The nonce used for this claim
     */
    event RewardClaimed(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed nonce,
        bytes signature
    );

    /**
     * @notice Emitted when the reward signer is updated
     * @param oldSigner The previous signer address
     * @param newSigner The new signer address
     */
    event RewardSignerUpdated(
        address indexed oldSigner,
        address indexed newSigner
    );

    /**
     * @notice Updates the address authorized to sign reward messages
     * @param newSigner The new signer address
     */
    function setRewardSigner(address newSigner) external;

    /**
     * @notice Withdraws all remaining tokens from the reward contract
     * @param to Recipient address for the withdrawn tokens
     */
    function withdrawRemainingTokens(address to) external;

    /**
     * @notice Claims a signed reward
     * @param reward    The reward data (user, amount, nonce)
     * @param signature EIP-712 signature from the reward signer
     */
    function claimReward(Reward calldata reward, bytes calldata signature) external;
}


