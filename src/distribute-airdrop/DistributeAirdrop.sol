// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IDistributeAirdrop} from "./IDistributeAirdrop.sol";
import {AccessRestriction} from "../accessRistriction/AccessRestriction.sol";

/**
 * @title DistributeAirdrop
 * @notice Upgradeable bulk sender for ERC20 tokens. Uses transferFrom so
 *         the caller must approve this contract for the total amount.
 */
contract DistributeAirdrop is Initializable, UUPSUpgradeable, IDistributeAirdrop {

    // ========== Storage ==========
    IERC20 public token;
    AccessRestriction public accessRestriction;

        /**
     * @notice Modifier to restrict access to manager role
     */
    modifier onlyManager() {
        if (!accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), msg.sender)) revert CallerNotManager();
        _;
    }

    
    /**
     * @notice Modifier to restrict access to admin role
     */
    modifier onlyAdmin() {
        if (!accessRestriction.hasRole(accessRestriction.ADMIN_ROLE(), msg.sender)) revert CallerNotAdmin();
        _;
    }



    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ========== Initializer ==========
    function initialize(address _token) external initializer {
        __UUPSUpgradeable_init();

        if (_token == address(0)) revert ZeroAddress();

        token = IERC20(_token);
    }

    // ========== Actions ==========
    function bulkTransfer(address[] calldata recipients, uint256[] calldata amounts)
        external
        override
        onlyManager
    {
        if (recipients.length != amounts.length) revert LengthMismatch();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            address to = recipients[i];
            uint256 amount = amounts[i];
            if (to == address(0)) revert ZeroAddress();
            if (amount == 0) revert ZeroAmount();
            totalAmount += amount;
            // transferFrom the sender (msg.sender) to each recipient
            bool success = token.transferFrom(msg.sender, to, amount);
            if (!success) revert TransferFromFailed();
        }

        emit BulkTransfer(msg.sender, recipients.length, totalAmount);
    }

    // ========== Upgrades ==========
    function _authorizeUpgrade(address) internal override onlyAdmin {}
}

