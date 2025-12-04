// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IAirdrop } from "./IAirdrop.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessRestriction } from "../accessRistriction/AccessRestriction.sol";

/**
 * @title Airdrop
 * @notice Helper contract to batch-send MTX tokens using `transferFrom`.
 *
 * @dev Usage:
 * - Deploy this contract with the MTX token address and AccessRestriction.
 * - The `from` address must approve this contract to spend its MTX tokens.
 * - Only addresses with MANAGER_ROLE can call `batchAirdropFrom`.
 * - Call `batchAirdropFrom(from, recipients, amounts)` to send tokens in batch.
 */
contract Airdrop is IAirdrop {
    /// @notice MTX token contract
    IERC20 public immutable mtxToken;

    /// @notice Access restriction contract
    AccessRestriction public immutable accessRestriction;

    /// @notice Mapping to track addresses that have already received an airdrop
    mapping(address => bool) public hasReceivedAirdrop;

    /// @notice Error thrown when caller is not a manager
    error CallerNotManager();

    /// @notice Error thrown when recipient has already received an airdrop
    error RecipientAlreadyAirdropped(address recipient);

    /// @notice Error thrown when recipient has already received an airdrop
    error ZeroAddressOrZeroAmount(address recipient);

    /**
     * @notice Modifier to restrict access to manager role
     */
    modifier onlyManager() {
        if (!accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    /**
     * @notice Set the MTX token contract address and AccessRestriction.
     * @param _mtxToken Address of the MTX token (IERC20)
     * @param _accessRestriction Address of the AccessRestriction contract
     */
    constructor(address _mtxToken, address _accessRestriction) {
        require(_mtxToken != address(0), "Airdrop: invalid MTX token");
        require(_accessRestriction != address(0), "Airdrop: invalid AccessRestriction");
        mtxToken = IERC20(_mtxToken);
        accessRestriction = AccessRestriction(_accessRestriction);
    }

    /**
     * @inheritdoc IAirdrop
     */
    function batchAirdropFrom(
        address from,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external override onlyManager {
        require(from != address(0), "Airdrop: invalid from");
        uint256 length = recipients.length;
        require(length == amounts.length, "Airdrop: length mismatch");

        for (uint256 i = 0; i < length; i++) {
            address to = recipients[i];
            uint256 amount = amounts[i];

            if (to == address(0) || amount == 0) {
                revert ZeroAddressOrZeroAmount(to);
            }

            if (hasReceivedAirdrop[to]) {
                revert RecipientAlreadyAirdropped(to);
            }

            bool success = mtxToken.transferFrom(from, to, amount);
            
            require(success, "Airdrop: transfer failed");

            hasReceivedAirdrop[to] = true;
            
            emit TokensAirdropped(msg.sender, from, to, amount);
        }
    }
}



