# EverlongERC4626

[Git Source](https://github.com/delvtech/everlong/blob/a882cfe2c27e9b8d9d3084f5dd6ac8776571789b/contracts/ERC4626.sol)

**Inherits:**
ERC4626

**Author:**
DELV

Everlong ERC4626 vault compatibility and functionality.

## State Variables

### useVirtualShares

Virtual shares are used to mitigate inflation attacks.

```solidity
bool public constant useVirtualShares = true;
```

### decimalsOffset

Used to reduce the feasibility of an inflation attack.
TODO: Determine the appropriate value for our case. Current value
was picked arbitrarily.

```solidity
uint8 public constant decimalsOffset = 3;
```

### hyperdrive

Address of the Hyperdrive instance wrapped by Everlong.

```solidity
address public immutable hyperdrive;
```

### \_baseAsset

ERC20 token used for deposits, idle liquidity, and
the purchase of bonds from the Hyperdrive instance.
This is also the underlying Hyperdrive instance's
vaultSharesToken.

```solidity
address internal immutable _baseAsset;
```

### \_decimals

Decimals used by the {\_baseAsset}.

```solidity
uint8 internal immutable _decimals;
```

### \_name

Name of the Everlong token.

```solidity
string internal _name;
```

### \_symbol

Symbol of the Everlong token.

```solidity
string internal _symbol;
```

## Functions

### constructor

Initializes parameters for Everlong's ERC4626 functionality.

```solidity
constructor(address hyperdrive_, string memory name_, string memory symbol_);
```

**Parameters**

| Name          | Type      | Description                                             |
| ------------- | --------- | ------------------------------------------------------- |
| `hyperdrive_` | `address` | Address of the Hyperdrive instance wrapped by Everlong. |
| `name_`       | `string`  | Name of the ERC20 token managed by Everlong.            |
| `symbol_`     | `string`  | Symbol of the ERC20 token managed by Everlong.          |

### asset

_Address of the underlying Hyperdrive instance._

_MUST be an ERC20 token contract._

_MUST NOT revert._

```solidity
function asset() public view virtual override returns (address);
```

### name

_Returns the name of the Everlong token._

```solidity
function name() public view virtual override returns (string memory);
```

### symbol

_Returns the symbol of the Everlong token._

```solidity
function symbol() public view virtual override returns (string memory);
```

### \_useVirtualShares

_Returns whether virtual shares will be used to mitigate the inflation attack._

_See: https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3706_

_MUST NOT revert._

```solidity
function _useVirtualShares() internal view virtual override returns (bool);
```

### \_underlyingDecimals

_Returns the number of decimals of the underlying asset._

_MUST NOT revert._

```solidity
function _underlyingDecimals() internal view virtual override returns (uint8);
```

### \_decimalsOffset

_A non-zero value used to make the inflation attack even more unfeasible._

_MUST NOT revert._

```solidity
function _decimalsOffset() internal view virtual override returns (uint8);
```

### \_beforeWithdraw

```solidity
function _beforeWithdraw(uint256, uint256) internal override;
```

### \_afterDeposit

```solidity
function _afterDeposit(uint256, uint256) internal override;
```
