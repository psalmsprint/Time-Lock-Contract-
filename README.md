# TimeLock Contract

A smart contract mechanism that delays transaction execution until a predetermined time period elapses, providing a mandatory waiting period for stakeholders to review and potentially cancel unwanted changes before they take effect.

## Why?

Without timelock:
- Governance votes → Changes happen instantly
- No time to review or exit

With timelock:
- Governance votes → Wait 2 days → Then execute
- Users can review and leave if they disagree

**Used by:** Compound, Uniswap, Aave, MakerDAO

## How It Works

```
1. Queue transaction → Store it with execution time
2. Wait (minimum delay) → Forced waiting period  
3. Execute → After delay, within grace period
```

## Install

```bash
forge install
forge test
```

## Usage

```solidity
// Deploy
TimeLockContract timelock = new TimeLockContract(
    governor,  // who can queue/execute
    2 days,    // minimum delay
    5 days     // grace period
);

// Queue transaction
timelock.queueTransaction(
    0,                    // txId
    targetContract,       // what to call
    0,                    // ETH to send
    data,                 // function call
    block.timestamp + 2 days  // when to execute
);

// Wait 2 days...

// Execute
timelock.executeTransaction(0);
```

## Features

- ✅ Enforced delays (min 1 day)
- ✅ Grace period for execution
- ✅ Reentrancy protection
- ✅ Cancel queued transactions
- ✅ 100% test coverage

## Functions

**queueTransaction** - Queue a transaction for later  
**executeTransaction** - Execute after delay  
**cancelTransaction** - Cancel before execution  
**waitTransaction** - Check if delay passed

## Config

- **Minimum Delay**: 1+ days (gives users time to react)
- **Grace Period**: 3+ days (execution window)

## Example: DAO Upgrade

```solidity
// 1. DAO votes to upgrade treasury
// 2. Queue upgrade via timelock
timelock.queueTransaction(1, treasury, 0, upgradeData, executeTime);

// 3. Users have 2 days to:
//    - Review new code
//    - Discuss in community
//    - Exit if they disagree

// 4. After 2 days, execute
timelock.executeTransaction(1);
```

## Security

- Reentrancy guard on execute
- State updates before external calls
- Transactions expire if not executed in time

## License

MIT

---

Built by [0xNicos](https://twitter.com/0xNicos) 