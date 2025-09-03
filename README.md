# MEV-Coin

MEV-Coin is a cryptocurrency to make theconcept of MEV (Miner Extractable Value) more vivisble to users that don't operate blockchain nodes themselves. It is an ERC-20 token that runs on Ethereum-compatible blockchains.

## How does MEV-Coin interact with MEV?

On every block that has block number devisible by 100, the first MEV-Coin transfer will mint 100 new MEV-Coins to the recipient of that transfer. This means that if you send MEV-Coin to someone, and the transaction is included in a block with a number that is devisible by 100, the recipient will receive 100 additional MEV-Coin if you transaction is the first MEV-Coin transfer in that block.
This mechanism is designed to illustrate the concept of MEV, as miners (or validators) can choose which transactions to include in a block and in what order, potentially extracting value from users by prioritizing certain transactions.

## How does MEV-Coin work?

MEV-Coin is implemented as an ERC-20 token using Solidity. The contract includes a custom transfer function that checks the block number and mints new tokens accordingly. When a transfer is made, the contract checks if the block number is devisible by 100 and whether it already minted the additional tokens for that block. If not, it mints 100 new MEV-Coins to the recipient and saves the infomation that tokens have been minted for that block.

## How are the initial MEV-Coins distributed?

There are no initial MEV-Coins. The only way to obtain MEV-Coins is through transfers that trigger the minting mechanism. To make this possible, transfers of zero value are allowed.

## Where can I see MEV-Coin in action?

It is deployed on the [Celo Sepolia network](https://docs.celo.org/network/celo-sepolia) at [0x3c257c32Ac296d20D86D9F8bD6225915F830aa0E](https://celo-sepolia.blockscout.com/address/0x3c257c32Ac296d20D86D9F8bD6225915F830aa0E).

## 📊 Dashboard

The MEV-Coin dashboard provides real-time statistics and analytics for MEV-Coin activity:

- **Live MEV Bonuses**: Track recent 100 MEV token bonuses awarded at 100-block intervals
- **Top Holders**: View addresses with the highest MEV-Coin balances
- **Contract Statistics**: Monitor total supply and current blockchain state

### Running the Dashboard

1. **Local Development**:
   ```bash
   cd scripts
   ./mev_dashboard.sh
   open ../docs/index.html
   ```

2. **GitHub Pages Deployment**:
   - The dashboard is configured for GitHub Pages in the `/docs` directory
   - Push to GitHub and enable Pages in repository settings
   - Set source to "Deploy from a branch" → "main" → "/docs folder"
   - Your dashboard will be live at `https://yourusername.github.io/repositoryname/`

### Prerequisites

- Local Ethereum node running on `localhost:8545` (e.g., Anvil)
- [Foundry](https://getfoundry.sh/) installed (`cast` command)
- MEV-Coin contract deployed and funded
