# Land Registry Smart Contract System

A decentralized land registry system built on Ethereum using smart contracts. This system allows for the secure registration, verification, and transfer of land ownership using NFTs.

## Features

- Land ownership represented as NFTs
- Role-based access control
- Multiple verification steps for land registration
- Secure transfer process with witness system
- IPFS integration for document storage

## Roles

1. **Patwari**: Creates land drafts and registers officials
2. **Clerk**: Verifies drafts and transfers
3. **Tehsildar**: Approves or rejects drafts and transfers
4. **Registrar**: Manages NFT minting and transfer completion

## Setup

1. Clone the repository:
```bash
git clone <your-repo-url>
cd landregistory
```

2. Install dependencies:
```bash
npm install
```

3. Compile contracts:
```bash
npx hardhat compile
```

4. Run tests:
```bash
npx hardhat test
```

## Contract Structure

- `ILandRegistry.sol`: Interface defining core structures and events
- `LandRegistryStorage.sol`: Base storage contract
- `Patwari.sol`: Patwari role functionality
- `Clerk.sol`: Clerk role functionality
- `Tehsildar.sol`: Tehsildar role functionality
- `Registrar.sol`: Registrar role functionality
- `LandRegistry.sol`: Main contract combining all roles

## License

MIT 