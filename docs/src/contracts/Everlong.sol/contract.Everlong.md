# Everlong

[Git Source](https://github.com/delvtech/everlong/blob/a882cfe2c27e9b8d9d3084f5dd6ac8776571789b/contracts/Everlong.sol)

**Inherits:**
[EverlongERC4626](/contracts/ERC4626.sol/contract.EverlongERC4626.md), [Admin](/contracts/Admin.sol/contract.Admin.md), [Positions](/contracts/Positions.sol/contract.Positions.md)

**Author:**
DELV

,---..-. .-.,---. ,---. ,-. .---. .-. .-. ,--,
| .-' \ \ / / | .-' | .-.\ | | / .-. ) | \| |.' .'
| `-.  \ V /  | `-. | `-'/  | |   | | |(_)|   | ||  |  __
| .-'   ) /   | .-'  |   (   | |   | | | | | |\  |\  \ ( _)
|  `--.(_) | `--.| |\ \  | `--.\ `-' / | | |)| \  `-) )
( **.' /( **.'|_| \)\ |( **.')---' /( (\_) )\_\_**/
(**) (**) (**)(_) (_) (**) (\_\_)

A money market powered by Hyperdrive.

## Functions

### constructor

```solidity
constructor(
  string memory name_,
  string memory symbol_,
  address underlying_
) Admin() EverlongERC4626(underlying_, name_, symbol_);
```
