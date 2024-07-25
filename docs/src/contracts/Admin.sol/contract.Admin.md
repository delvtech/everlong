# Admin

[Git Source](https://github.com/delvtech/everlong/blob/a882cfe2c27e9b8d9d3084f5dd6ac8776571789b/contracts/Admin.sol)

**Inherits:**
[IAdmin](/contracts/interfaces/IAdmin.sol/interface.IAdmin.md)

## State Variables

### admin

Gets the admin address of the Everlong instance.

```solidity
address public admin;
```

## Functions

### onlyAdmin

_Ensures that the contract is being called by admin._

```solidity
modifier onlyAdmin();
```

### constructor

_Initialize the admin address to the contract deployer._

```solidity
constructor();
```

### setAdmin

Allows admin to transfer the admin role.

```solidity
function setAdmin(address _admin) external onlyAdmin;
```

**Parameters**

| Name     | Type      | Description            |
| -------- | --------- | ---------------------- |
| `_admin` | `address` | The new admin address. |
