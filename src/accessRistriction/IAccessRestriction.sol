// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IAccessRestriction
 * @notice Interface for AccessRestriction contract
 */
interface IAccessRestriction is IAccessControl {
    
    function pause() external;
    
    function unpause() external;
}
