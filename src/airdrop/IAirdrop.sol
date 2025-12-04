// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IAirdrop
 * @notice Interface for MTX token airdrop helper contract
 *
 * @dev This contract is intended to batch-send MTX tokens using `transferFrom`.
 *      The caller (or another address) must approve this contract to spend
 *      enough MTX tokens before calling the batch function.
 */
interface IAirdrop {
    /**
     * @notice Emitted for every successful MTX transfer in a batch.
     * @param operator The account that initiated the airdrop transaction (msg.sender)
     * @param from     The address from which MTX tokens are pulled via transferFrom
     * @param to       The recipient address
     * @param amount   The amount of MTX tokens sent
     */
    event TokensAirdropped(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    /**
     * @notice Batch-send MTX tokens from a single address to many recipients.
     *
     * @dev Requirements:
     * - `from` must have approved this contract to spend at least the sum of `amounts`.
     * - `recipients.length` must equal `amounts.length`.
     *
     * @param from        The address whose MTX tokens will be sent (source of tokens)
     * @param recipients  The list of recipient addresses
     * @param amounts     The list of amounts to send to each recipient
     */
    function batchAirdropFrom(
        address from,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;
}


