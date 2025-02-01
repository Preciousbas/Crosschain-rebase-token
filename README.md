## Cross-Chain Rebase Token Protocol

## Overview

The Cross-Chain Rebase Token Protocol is an innovative blockchain solution designed to enable users to deposit assets into a vault and receive dynamically rebasing tokens in return. These tokens continuously reflect the user's underlying balance growth based on a predetermined interest rate. Additionally, the protocol supports cross-chain interoperability, allowing seamless asset transfers between networks such as Ethereum Sepolia Testnet and ZkSync.

### Features

⦁ Rebase Token ($RBT): An ERC-20 token with a dynamic balanceOf function that increases a user’s balance linearly over time.

⦁ Vault Mechanism: Users deposit native ETH (or testnet Sepolia ETH) into a vault and receive $RBT in return, tied to the vault's global interest rate.

⦁ Interest Rate System:

&nbsp;◾ Users are assigned an interest rate equal to the global rate at the time of deposit.

&nbsp;◾ The global interest rate is designed to only decrease over time, incentivizing early adopters.

⦁ Cross-Chain Bridging:

&nbsp;◾ $RBT tokens can be transferred between supported networks.

&nbsp;◾ The bridgeToZkSync.sh script facilitates cross-chain bridging between Sepolia Testnet ETH and ZkSync.

⦁ Dynamic Token Growth:

&nbsp;◾ Rebase tokens increase based on a linear time function.

&nbsp;◾ Users receive additional tokens when performing actions such as minting, burning, transferring, or bridging.

## Smart Contract Components

### Rebase Token (ERC-20: $RBT)

⦁ Implements a modified balanceOf(address user) function that dynamically calculates the user's balance based on elapsed time and interest rate.

⦁ Allows minting and burning by the vault and other authorized contracts.

### Vault Contract

⦁ Accepts deposits of native ETH (or testnet ETH) and mints $RBT to users.

⦁ Assigns interest rates to users at the time of deposit.

⦁ Manages global interest rate adjustments.

### Cross-Chain Bridge Mechanism

⦁ Utilizes Chainlink CCIP or other bridge solutions to facilitate seamless asset transfers between Ethereum Sepolia Testnet and ZkSync.

⦁ The bridgeToZkSync.sh script automates the bridging process.

## Getting Started

### Requirements

⦁ git

⦁ Foundry

```shell
foundryup
```

⦁ Foundry-zksync: For ZKSync implementation

```shell
curl -L https://raw.githubusercontent.com/matter-labs/foundry-zksync/main/install-foundry-zksync | bash
```

### Quickstart

```shell
git clone https://github.com//Preciousbas/Crosschain-rebase-token
cd Crosschain-rebase-token
forge install
forge build
```

## Deploy Contracts

### Scripts

Instead of scripts, we can directly use the cast command to interact with the contract.

For example, on Sepolia:

&nbsp;1. Get some RebaseTokens

```shell
cast send <vault-contract-address> "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --wallet
```

&nbsp;2. Redeem RebaseTokens for ETH

```shell
cast send <vault-contractaddress> "redeem(uint256)" 10000000000000000 --rpc-url $SEPOLIA_RPC_URL --wallet
```

### Bridge ETH to ZkSync

Run the following command to bridge ETH from Sepolia Testnet to ZkSync:

```shell
./bridgeToZkSync.sh
```

## Security Considerations

&nbsp;⦁ Reentrancy Protection: Implemented in the vault to prevent unauthorized withdrawals.

&nbsp;⦁ Interest Rate Limits: Prevents malicious actors from manipulating global interest rates.

&nbsp;⦁ Chain Selector Verification: Ensures correct cross-chain transactions by verifying chain selectors before execution.

## Contact

For questions, open an issue on GitHub or reach out via preciousasuquo6@gmail.com
