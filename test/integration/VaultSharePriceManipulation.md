# Problems

## Share Price Decrease

The share price decreases for subsequent deposits within a checkpoint.

This creates an incentive to deposit immediately after another deposit.

## Sandwich

Sandwiching a deposit in Everlong with opening/closing a short in Hyperdrive
allows the attacker to enter at a more favorable share price.

# Results

**Share Delta %:** (attacker_shares - bystander_shares) / bystander_shares

## Base Case

- Portfolio value calculated w/ `previewCloseLong` and weighted avg maturity.

### No Sandwich: 1x Initial - 0x Short - 1x Deposit

```
Initial Deposit:     1e20
Bystander Deposit:   1e20
Sandwich Short:      0e0
Sandwich Deposit:    1e20
```

#### No Sandwich - Instant

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0488454543199769 | -0.0808584087950621   | -0.0325529410870792  |

#### No Sandwich - Half Term

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0488454543199769 | 2.4102622262568446    | 2.4597844931566773   |

#### No Sandwich - Full Term

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0488454543199769 | 4.812675977410781     | 4.8633717142220104   |

### No Sandwich: 1x Initial - 0x Short - 100x Deposit

```
Initial Deposit:     1e20
Bystander Deposit:   1e20
Sandwich Short:      0e0
Sandwich Deposit:    1e22
```

#### No Sandwich - Instant

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | -0.1439539091280853   | -0.0956792607038956  |

#### No Sandwich - Half Term

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | 2.3455390525956628    | 2.3950297051672703   |

#### No Sandwich - Full Term

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | 4.746290765614268     | 4.7969540762671941   |

### Sandwich: 1x Initial - 1x Short - 1x Deposit

```
  Initial Deposit:     1e20
  Bystander Deposit:   1e20
  Sandwich Short:      1e20
  Sandwich Deposit:    1e20
```

#### Sandwich - Instant

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0488493110012635 | -0.0808620996899046   | -0.0325527802413559  |

#### Sandwich - Half Term

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0488493110012635 | 2.4102603620484712    | 2.4597865776557769   |

#### Sandwich - Full Term

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0488493110012635 | 4.8126758734414512    | 4.8633756524734598   |

### Sandwich: 1x Initial - 100x Short - 1x Deposit

```
  Initial Deposit:     1e20
  Bystander Deposit:   1e20
  Sandwich Short:      1e22
  Sandwich Deposit:    1e20
```

#### Sandwich - Instant

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0492311119624823 | -0.0812274633882695   | -0.0325368334933336  |

#### Sandwich - Half Term

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0492311119624823 | 2.4100758171022951    | 2.4599929433045743   |

#### Sandwich - Full Term

| Share Delta (%)    | Bystander Profits (%) | Attacker Profits (%) |
| ------------------ | --------------------- | -------------------- |
| 0.0492311119624823 | 4.8126655994419425    | 4.8637655473099645   |

### Sandwich: 1x Initial - 100x Short - 100x Deposit

```
  Initial Deposit:     1e20
  Bystander Deposit:   1e20
  Sandwich Short:      1e22
  Sandwich Deposit:    1e22
```

#### Sandwich - Instant

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | -0.1443275920235055   | -0.0956680270235465  |

#### Sandwich - Half Term

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | 2.3453477763866673    | 2.3952330362547507   |

#### Sandwich - Full Term

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | 4.7462752877077818    | 4.7973425508871018   |

### Sandwich: 100x Initial - 100x Short - 100x Deposit

```
  Initial Deposit:     1e22
  Bystander Deposit:   1e20
  Sandwich Short:      1e22
  Sandwich Deposit:    1e22
```

#### Sandwich - Instant

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | -0.0498977200171917   | -0.0485557261485902  |

#### Sandwich - Half Term

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | 2.4420896203783222    | 2.4434653203562377   |

#### Sandwich - Full Term

| Share Delta (%) | Bystander Profits (%) | Attacker Profits (%) |
| --------------- | --------------------- | -------------------- |
| x               | 4.845154275553862     | 4.8465624788911015   |

## Only Update `totalAssets` After Deposit

TLDR: Bad

```
[PASS] test_sandwich_immature() (gas: 93071089)
Logs:
Sandwich - Immature
Initial Deposit:     1e20
Bystander Deposit:   1e20
Sandwich Short:      0e0
Sandwich Deposit:    1e20
Time Close Short:    0
Time Close Everlong: 15768000
share delta percent:   -2.3344307083161762e16
bystander profits:  1.5225768262785863e16
attacker profits:   -8.378570341534672e15
------------------------------------------------------

[PASS] test_sandwich_instant() (gas: 92905751)
Logs:
Sandwich - Instant
Initial Deposit:     1e20
Bystander Deposit:   1e20
Sandwich Short:      0e0
Sandwich Deposit:    1e20
Time Close Short:    0
Time Close Everlong: 0
share delta percent:   -2.3344307083161762e16
bystander profits:  -9.438709848318052e15
attacker profits:   -3.256290376898564e16
------------------------------------------------------

[PASS] test_sandwich_mature() (gas: 93273231)
Logs:
Sandwich - Mature
Initial Deposit:     1e20
Bystander Deposit:   1e20
Sandwich Short:      0e0
Sandwich Deposit:    1e20
Time Close Short:    0
Time Close Everlong: 31536001
share delta percent:   -2.3344307083161762e16
bystander profits:  3.9074051424698906e16
attacker profits:   1.481736070797418e16
------------------------------------------------------
```
