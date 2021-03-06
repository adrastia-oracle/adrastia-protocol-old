// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "./IRoleManager.sol";

contract RoleManager is AccessControlEnumerable, IRoleManager {}
