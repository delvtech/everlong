# IEverlong

[Git Source](https://github.com/delvtech/everlong/blob/a882cfe2c27e9b8d9d3084f5dd6ac8776571789b/contracts/interfaces/IEverlong.sol)

**Inherits:**
IERC4626, [IAdmin](/contracts/interfaces/IAdmin.sol/interface.IAdmin.md), [IPositions](/contracts/interfaces/IPositions.sol/interface.IPositions.md)

## Functions

### kind

Gets the Everlong instance's kind.

```solidity
function kind() external pure returns (string memory);
```

**Returns**

| Name     | Type     | Description                   |
| -------- | -------- | ----------------------------- |
| `<none>` | `string` | The Everlong instance's kind. |

### version

Gets the Everlong instance's version.

```solidity
function version() external pure returns (string memory);
```

**Returns**

| Name     | Type     | Description                      |
| -------- | -------- | -------------------------------- |
| `<none>` | `string` | The Everlong instance's version. |
