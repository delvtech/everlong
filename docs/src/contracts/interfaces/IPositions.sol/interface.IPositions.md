# IPositions

[Git Source](https://github.com/delvtech/everlong/blob/a882cfe2c27e9b8d9d3084f5dd6ac8776571789b/contracts/interfaces/IPositions.sol)

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
function getPosition(uint256 _index) external view returns (Position memory);
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
function rebalance() external;
```

## Events

### PositionAdded

Emitted when a new position is added.
TODO: Include wording for distinct maturity times if appropriate.
TODO: Reconsider naming https://github.com/delvtech/hyperdrive/pull/1096#discussion_r1681337414

```solidity
event PositionAdded(
  uint128 indexed maturityTime,
  uint128 bondAmount,
  uint256 index
);
```

### PositionUpdated

Emitted when an existing position's `bondAmount` is modified.
TODO: Reconsider naming https://github.com/delvtech/hyperdrive/pull/1096#discussion_r1681337414

```solidity
event PositionUpdated(
  uint128 indexed maturityTime,
  uint128 newBondAmount,
  uint256 index
);
```

### Rebalanced

Emitted when Everlong's underlying portfolio is rebalanced.

```solidity
event Rebalanced();
```

## Structs

### Position

_Tracks the total amount of bonds managed by Everlong
with the same maturityTime._

```solidity
struct Position {
  uint128 maturityTime;
  uint128 bondAmount;
}
```
