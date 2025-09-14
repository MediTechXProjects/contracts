// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { IAccessRestriction } from "./IAccessRestriction.sol";
/**
 * @title AccessRestriction
 * @notice Contract that handles access control and pausable functionality
 */
contract AccessRestriction is AccessControl, Pausable , IAccessRestriction {
    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    
    constructor(address _admin, address _treasury) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(TREASURY_ROLE, _treasury);

    }
    
    /**
     * @notice Modifier to restrict access to manager role
     */
    modifier onlyManager() {
        require(hasRole(MANAGER_ROLE, _msgSender()), "AccessRestriction: caller is not a manager");
        _;
    }

    /**
     * @notice Modifier to restrict access to admin role
     */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccessRestriction: caller is not an admin");
        _;
    }

    /**
     * @notice Modifier to restrict access to treasury role
     */
    modifier onlyTreasury() {
        require(hasRole(TREASURY_ROLE, _msgSender()), "AccessRestriction: caller is not treasury");
        _;
    }
    
    /**
     * @notice Pause all operations
     */
    function pause() external override onlyManager {
        _pause();
    }

    /**
     * @notice Unpause all operations
     */
    function unpause() external override onlyManager {
        _unpause();
    }
}
