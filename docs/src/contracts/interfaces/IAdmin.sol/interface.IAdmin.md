# IAdmin

[Git Source](https://github.com/delvtech/everlong/blob/a882cfe2c27e9b8d9d3084f5dd6ac8776571789b/contracts/interfaces/IAdmin.sol)

## Functions

### admin

Gets the admin address of the Everlong instance.

```solidity
function admin() external view returns (address);
```

**Returns**

| Name     | Type      | Description                                  |
| -------- | --------- | -------------------------------------------- |
| `<none>` | `address` | The admin address of this Everlong instance. |

### setAdmin

Allows admin to transfer the admin role.

```solidity
function setAdmin(address _admin) external;
```

**Parameters**

| Name     | Type      | Description            |
| -------- | --------- | ---------------------- |
| `_admin` | `address` | The new admin address. |

## Events

### AdminUpdated

Emitted when admin is transferred.

```solidity
event AdminUpdated(address indexed admin);
```

## Errors

### Unauthorized

Thrown when caller is not the admin.

```solidity
error Unauthorized();
```
