// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDistributeAirdrop {
    // ========== Errors ==========
    error LengthMismatch();
    error ZeroAddress();
    error ZeroAmount();
    error CallerNotManager();
    error CallerNotAdmin();
    error TransferFromFailed();

    // ========== Events ==========
    event BulkTransfer(address indexed sender, uint256 recipients, uint256 totalAmount);

    // ========== Actions ==========
    function bulkTransfer(address[] calldata recipients, uint256[] calldata amounts) external;
}

