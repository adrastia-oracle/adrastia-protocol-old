// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

abstract contract IVersionable {
    function version() public view virtual returns (uint256);

    function handleUpgrade(uint256 fromVersion, uint256 toVersion) internal virtual;
}
