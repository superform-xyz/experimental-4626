# Experimental ERC-4626 Repository

### Introduction - MultiVault Extension

Extends ERC4626 original functions with a minimal addition to the original interface. Copies ERC4626 architectual approach to the standarization of single Vaults onto MultiVault design. Introduces ERC1155 as LP (shares) managment token and a tool for embedding multiple ERC4626 underlying(s) within one MultiVault contract. Provides high modularity with encoded `vaultData` variable, presented through sample implementation in `MultiCore.sol`, allowing for each `vaultId` to have it's own modules, additional interfaces or metadata. Keeps easy to extend by inheritance interface.

### Rationale

ERC4626 is operating only on one underlying token, minting in return one ERC20 shares token, all within one - single - Vault contract, needed to be redeployed for each new underlying asset and it's accounting logic. Additionally, often requested and found in-the-wild, not provided by ERC4626 feature, is ability to operate on multiple assets with separate accounting still within single Vault contract. ERC4626 standard can itself be inherited and overriden (and such is the expectation) through parent contracts, initialized by other contract or made to use as an instance.

However, arguments for potential standardized extension exist. Found reccuring patterns hold true across many non-4626 Vaults and can be accomodated with small logical changes to the existing ERC4626 interface while still keeping extension intuitive for developers already working with ERC4626. To that, we demonstrate alpha version of `MultiCore.sol` implementation contract, utilizing our proposed `MultiVault.sol` extension of the ERC4626.

Currently multiple underlying tokens standarization within single ERC4626 vault is an object of on-going research for most uniform proposition (refer to `research` directory). For the time being we present prototype of potential extension to the ERC4626 focused on accounting operations within single contract for multiple Vault assets.

### Changes to ERC4626:

- ERC1155 as shares / lp token for Vault
- `totalSupply` of vaultIds (ERC1155 id)
- multiple singular vaults within one contract
  - each `vaultId` has it's own underlying and additional data params (`vaultData` is suppose to be very flexible without breaking)
    - `bytes vaultData` is intended to hold (string, interface, integer...) any data as long as decoding of its value is provided within `previewData()` function
    - `vaultData` is expected to be used internally and freely by implementation logic.
- `create(ERC20 asset, uin256 vaultData)` function to add new vault within core vault contract
- `previewData(uint256 vaultId)` function for reading decoded vaultData (check usage in `MultiVault.sol`)
  - can be implemented freely as long as it's returning appropriate `bytes data`. implementation of this function can have an effect inside of `afterDeposit()` or `beforeWithdraw()` functions, e.g _do something specific based on `vaultData` after deposit_. example implementation is `uri()` functions, reading metadata url from `vaultData` variable.
  - parent contract can extend this logic as it sees fit. e.g `setData()`. those functions should not be a part of extension. interface assumes that each vault has data, empty state may just be omitted.

_Disclaimer: Super WIP. Exploratory work and designs_

## Common Patterns

Three reccuring patterns for all currently researched multiVaults, warranting one common interface:

1. Reccuring `uint256 indexOfAssets` variable for any sort of id tracking. True for underlying assets, shares, supplies & balances or even whole Vaults (ERC1155 MultiVault)
2. Reccuring pattern of addition of another token interface through initialization in existing contract - `create()` function
3. Reccuring pattern of creation of separate accounting calculations for some type of assets/shares - `fund()`, `defund()` and it's `previewFund/Defund()` functions. *WORK IN PROGRESS - fund/defund logic will most likley be an extension itself*

# Contracts

Repository is divided into _research_ part, found inside `/contracts/research`. Those contracts were used to study potential design patterns for MultiVault extension. The effect of those explorations is found in `core` and only `core` contracts should be considered as MultiVault valid implementations. At the same time _research contracts_ are expected to serve a role of a demonstration on how developers could possibly use ERC4626 outside of *classic DeFi* yield bearing vault.

## Research Contracts

Three most common features of multi assets/shares Vaults abstracted to minimal examples presented in contracts described below.

1. `MultiVault.sol` ERC1155 extension (Vault-portfolio extension)
   - Changes EIP4626 interface, adds index to track LP-positions
   - Single ERC1155 as LP-token, each id == different Vault accounting
   - Each VaultId (ERC1155 id) has its own separate underlying balance
   - Only 1 type of share minted per id, single underlying allowed per id, each underlying follows its own logic (separate totalAssets())
2. `MultiUnderlyingVault.sol` (More than 1 token used as underlying asset)
   - Base underlying follows EIP4626 completly. Other underlying (here, _funding_) has it's own accounting logic. However, calculations depend on balances of all underlyings.
   - Single ERC20 as LP-token (share)
   - Each underlying has it's own separate balance, but operates within single vault
   - totalAssets should return balance of ALL underlying
   - NOTE: This overlaps with `MultiSharesVault` in many aspects, but few.
3. `MultiSharesVault.sol` (Stablecoins)
   - Changes EIP4626 interface, adds index value to to keep track of types of accounting (not all deposits are equal)
   - Single ERC20 as LP-token (unchanged)
   - Only 1 underlying. Extension used to mint more than 1 type of share from Vault (ie. volmex volatility tokens)
   - totalAssets will be different depending on type of share owned by user

### Research - Assets logic

MultiVaults can opt for few different ways of managing `assets`. This slight change is reflected through assets/shares accounting calculations proposed in standard implementation of ERC4626.

1. MultiVault

```javascript
    mapping(uint256 => Vault) public vaults;

    /// @dev Vault Data
    struct Vault {
        ERC20 underlying;
        uint256 totalSupply;
    }
```

2. MultiUnderlyingVault

```javascript
    mapping(uint256 => ERC20) public _assets;
```

3. MultiSharesVault

```javascript
    mapping(uint256 => FundingToken) public _assets;
```

# Advanced Sample Hardhat Project

This project demonstrates an advanced Hardhat use case, integrating other tools commonly used alongside Hardhat in the ecosystem.

The project comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts. It also comes with a variety of other tools, preconfigured to work with the project code.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.ts
TS_NODE_FILES=true npx ts-node scripts/deploy.ts
npx eslint '**/*.{js,ts}'
npx eslint '**/*.{js,ts}' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```

# Etherscan verification

To try out Etherscan verification, you first need to deploy a contract to an Ethereum network that's supported by Etherscan, such as Ropsten.

In this project, copy the .env.example file to a file named .env, and then edit it to fill in the details. Enter your Etherscan API key, your Ropsten node URL (eg from Alchemy), and the private key of the account which will send the deployment transaction. With a valid .env file in place, first deploy your contract:

```shell
hardhat run --network ropsten scripts/deploy.ts
```

Then, copy the deployment address and paste it in to replace `DEPLOYED_CONTRACT_ADDRESS` in this command:

```shell
npx hardhat verify --network ropsten DEPLOYED_CONTRACT_ADDRESS "Hello, Hardhat!"
```

# Performance optimizations

For faster runs of your tests and scripts, consider skipping ts-node's type checking by setting the environment variable `TS_NODE_TRANSPILE_ONLY` to `1` in hardhat's environment. For more details see [the documentation](https://hardhat.org/guides/typescript.html#performance-optimizations).
