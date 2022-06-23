# Experimental ERC-4626 Repository

### Introduction - MultiVault Extension

MultiVault extends original ERC4626 functions with minimal additions to the original interface. The ERC4626 architectual approach to the standarization of single Vaults is translated onto a MultiVault design by introducing ERC1155 as LP (shares) managment token and as a tool for embedding multiple ERC4626 underlying(s) within one MultiVault contract. This contract maintains high modularity with an encoded `vaultData` variable, presented through sample implementation in `MultiCore.sol`, allowing for each `vaultId` to have it's own modules, additional interfaces or metadata. This is easy to extend through an inheritable interface.

### Rationale

ERC4626 currently only operates on one underlying token, minting in return one ERC20 shares token, all within one - single - Vault contract, and needs to be redeployed for each new underlying asset and it's accounting logic. Often requested functionality is the ability to operate on multiple assets with separate accounting still within single Vault contract. The ERC4626 standard was designed to be inherited and overriden (and such is the expectation) through parent contracts, initialized by other contract or made to use as an instance allowing for quick extending.

Despite this underlying flexibility, arguments for a potential standardized extension exist. Found reccuring patterns hold true across many non-4626 Vaults and can be accomodated with small logical changes to the existing ERC4626 interface while still keeping extension intuitive for developers already working with ERC4626. To that, we demonstrate alpha version of `MultiCore.sol` implementation contract, utilizing our proposed `MultiVault.sol` extension of the ERC4626.

The standardization of multiple underlying tokens within a single ERC4626 vault is an object of on-going research for most uniform proposition (refer to `research` directory). For the time being we present prototype of potential extension to the ERC4626 focused on accounting operations within single contract for multiple Vault assets.

### Changes to ERC4626:

- ERC1155 as shares / lp token for Vault
- `totalSupply` of vaultIds (ERC1155 id)
- multiple singular vaults within one contract
  - each `vaultId` has it's own underlying and additional data params (`vaultData` is suppose to be very flexible without breaking)
    - `bytes vaultData` is intended to hold (string, interface, integer...) any data as long as decoding of its value is provided within `previewData()` function
    - `vaultData` is expected to be used internally and freely by implementation logic.
- `create(ERC20 asset, uin256 vaultData)` function to add new vault within core vault contract
- `previewData(uint256 vaultId)` function for reading decoded vaultData (check usage in `MultiVault.sol`)
  - implementation of this function can have an effect inside of `afterDeposit()` or `beforeWithdraw()` functions, e.g _do something specific based on `vaultData` after deposit_. example implementation is `uri()` functions, reading metadata url from `vaultData` variable.
  - parent contract can extend this logic as it sees fit. e.g `setData()`. those functions should not be a part of extension. interface assumes that each vault has data, empty state may just be omitted.

_Disclaimer: WIP. Exploratory work and designs_

### Use cases

0. Batch focused testing + Curve integration testing

1. Yearn-like aggregator in single token with built-in rewards

- Using ERC1155 for managment of multiple Vaults, each with separate yield generating strategy
- Cutting approve costs through batching. Approve only MultiVault, get access to all Vaults.
- Re-stake your ALL positions (ERC1155 ids) and get a reward calculated from ALL positions
- Custom and separate logic executed for yield generation in `afterDeposit()`

2. Long/Short Vault for multiple collaterals?

### Differences between create Vault and add Vault

If pseudo-Vault is created through the additional ERC20 asset, MultiVault is a received of all asset balance and minter of one ERC1155-type share (denominated by ids)

If real-Vault is added, MultiVault acts as a router to it and receiver of LP-share from such.

## Common Patterns

Three reccuring patterns for all currently researched multiVaults, warranting one common interface:

1. Reccuring `uint256 indexOfAssets` variable for any sort of id tracking. True for underlying assets, shares, supplies & balances or even whole Vaults (ERC1155 MultiVault)
2. Reccuring pattern of addition of another token interface through initialization in existing contract - `create()` function
3. Reccuring pattern of creation of separate accounting calculations for some type of assets/shares - `fund()`, `defund()` and it's `previewFund/Defund()` functions. _WORK IN PROGRESS - fund/defund logic will most likley be an extension itself_

# Contracts

Repository is divided into _research_ part, found inside `/contracts/research`. Those contracts were used to study potential design patterns for MultiVault extension. The effect of those explorations is found in the root directory and here contracts should be considered MultiVault valid implementation. At the same time _research contracts_ are expected to serve a role of a demonstration on how developers could possibly use ERC4626 outside of _classic DeFi_ yield bearing vault.

## Research Contracts

Three most common features of multi assets/shares Vaults abstracted to minimal examples presented in contracts described below.

1. `MultiVault.sol` ERC1155 extension (Vault-portfolio extension)
   - Changes EIP4626 interface, adds index to track LP-positions
   - Single ERC1155 as LP-token, each id == different Vault accounting
   - Each VaultId (ERC1155 id) has its own separate underlying balance
   - Only 1 type of share minted per id, single underlying allowed per id, each underlying follows its own logic (separate totalAssets())
2. `MultiUnderlyingVault.sol` (More than 1 token used as underlying asset)
   - Base underlying follows EIP4626 completely. Other underlying (here, _funding_) has it's own accounting logic. However, calculations depend on balances of all underlyings.
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

# Install

`npm install`

`npx hardhat test`

Example tasks:

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