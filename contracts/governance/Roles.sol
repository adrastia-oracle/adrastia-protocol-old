// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

library Roles {
    bytes32 public constant SUPER = keccak256("SUPER_ROLE");

    bytes32 public constant ADMIN = keccak256("ADMIN_ROLE");

    bytes32 public constant INCENTIVE_MAINTAINER = keccak256("INCENTIVE_MAINTAINER_ROLE");

    bytes32 public constant WHITELIST_MAINTAINER = keccak256("WHITELIST_MAINTAINER_ROLE");

    /*
     * Timelock roles
     */
    bytes32 public constant TIMELOCK_ADMIN = keccak256("TIMELOCK_ADMIN_ROLE");

    bytes32 public constant TIMELOCK_PROPOSER = keccak256("TIMELOCK_PROPOSER_ROLE");

    bytes32 public constant TIMELOCK_EXECUTOR = keccak256("TIMELOCK_EXECUTOR_ROLE");
}
