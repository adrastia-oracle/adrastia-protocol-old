// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";

import "./RoleManager.sol";

abstract contract RoleConsumer is IAccessControlEnumerable {
    modifier onlyRole(bytes32 role) {
        _checkRole(role, msg.sender);
        _;
    }

    function permissionManager() public view virtual returns (RoleManager);

    function getRoleMember(bytes32 role, uint256 index) public view override returns (address) {
        return permissionManager().getRoleMember(role, index);
    }

    function getRoleMemberCount(bytes32 role) public view override returns (uint256) {
        return permissionManager().getRoleMemberCount(role);
    }

    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return permissionManager().hasRole(role, account);
    }

    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return permissionManager().getRoleAdmin(role);
    }

    function grantRole(
        bytes32, /*role*/
        address /*account*/
    ) external pure override {
        revert("RoleConsumer: READ_ONLY");
    }

    function revokeRole(
        bytes32, /*role*/
        address /*account*/
    ) external pure override {
        revert("RoleConsumer: READ_ONLY");
    }

    function renounceRole(
        bytes32, /*role*/
        address /*account*/
    ) external pure override {
        revert("RoleConsumer: READ_ONLY");
    }

    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "RoleConsumer: UNAUTHORIZED - account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }
}
