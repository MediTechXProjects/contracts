// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IAccessRestriction } from "./IAccessRestriction.sol";

/**
 * @title AccessRestriction
 * @notice Upgradeable contract that handles access control and pausable functionality
 */
contract AccessRestriction is
    Initializable,
    AccessControlUpgradeable, 
    PausableUpgradeable, 
    UUPSUpgradeable,
    IAccessRestriction
{
    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant MTX_CONTRACT_ROLE = keccak256("MTX_CONTRACT_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializer replaces constructor for upgradeable contracts
    function initialize(address _admin, address _treasury) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(TREASURY_ROLE, _treasury);
    }

    /// @notice Modifier to restrict access to admin role
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, _msgSender())) revert CallerNotAdmin();
        _;
    }

    /// @notice Pause all operations
    function pause() external override onlyAdmin {
        _pause();
    }

    /// @notice Unpause all operations
    function unpause() external override onlyAdmin {
        _unpause();
    }

    /// @notice Required by UUPS proxy
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
