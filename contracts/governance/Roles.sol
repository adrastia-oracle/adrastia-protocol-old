// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

library Roles {
    bytes32 public constant SUPER = keccak256("SUPER_ROLE");

    bytes32 public constant ADMIN = keccak256("ADMIN_ROLE");

    bytes32 public constant INCENTIVE_MAINTAINER = keccak256("INCENTIVE_MAINTAINER");

    bytes32 public constant WHITELIST_MAINTAINER = keccak256("WHITELIST_MAINTAINER");
}
