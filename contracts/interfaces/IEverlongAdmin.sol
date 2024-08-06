// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

interface IEverlongAdmin {
    // ╭─────────────────────────────────────────────────────────╮
    // │ Errors                                                  │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Thrown when caller is not the admin.
    error Unauthorized();

    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Allows admin to transfer the admin role.
    /// @param _admin The new admin address.
    function setAdmin(address _admin) external;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Gets the admin address of the Everlong instance.
    /// @return The admin address of this Everlong instance.
    function admin() external view returns (address);
}
