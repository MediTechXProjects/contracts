// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IAccessRestriction
 * @notice Interface for AccessRestriction contract
 */
interface IAccessRestriction is IAccessControl {
    
    function pause() external;
    
    function unpause() external;
}
