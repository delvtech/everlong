# Positions

[Git Source](https://github.com/delvtech/everlong/blob/a882cfe2c27e9b8d9d3084f5dd6ac8776571789b/contracts/Positions.sol)

**Inherits:**
[IPositions](/contracts/interfaces/IPositions.sol/interface.IPositions.md)

**Author:**
DELV

Accounting for the Hyperdrive bond positions managed by Everlong.

## State Variables

### \_positions

```solidity
DoubleEndedQueue.Bytes32Deque internal _positions;
```

## Functions

### getPositionCount

Gets the number of positions managed by the Everlong instance.

```solidity
function getPositionCount() external view returns (uint256);
```

**Returns**

| Name     | Type      | Description              |
| -------- | --------- | ------------------------ |
| `<none>` | `uint256` | The number of positions. |

### getPosition

Gets the position at an index.
Position `maturityTime` increases with each index.

```solidity
function getPosition(uint256 _index) public view returns (Position memory);
```

**Parameters**

| Name     | Type      | Description                |
| -------- | --------- | -------------------------- |
| `_index` | `uint256` | The index of the position. |

**Returns**

| Name     | Type       | Description   |
| -------- | ---------- | ------------- |
| `<none>` | `Position` | The position. |

### rebalance

Rebalances the Everlong bond portfolio if needed.

```solidity
function rebalance() external pure;
```
