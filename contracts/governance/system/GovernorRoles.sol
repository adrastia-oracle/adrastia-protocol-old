// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

library GovernorRoles {
    /// @notice Full-access role designed specifically for upgrading contracts.
    bytes32 public constant SUPER = keccak256("SUPER_ROLE");

    /// @notice Role for administrating timelock.
    bytes32 public constant TIMELOCK_ADMIN = keccak256("TIMELOCK_EXECUTOR_ROLE");

    /// @notice Role for executing timelock proposals.
    bytes32 public constant TIMELOCK_EXECUTOR = keccak256("TIMELOCK_EXECUTOR_ROLE");

    /// @notice Role for submitting proposals.
    bytes32 public constant TIMELOCK_PROPOSER = keccak256("TIMELOCK_PROPOSER_ROLE");
}
