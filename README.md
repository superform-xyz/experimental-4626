# Experimental ERC-4626 Repository

### Introduction - MultiVault Extension

MultiVault extends original ERC4626 functions with minimal additions to the original interface. The ERC4626 architectual approach to the standarization of single Vaults is translated onto a MultiVault design by introducing ERC1155 as LP (shares) managment token and as a tool for embedding multiple ERC4626 underlying(s) within one MultiVault contract. This contract maintains high modularity with an encoded `vaultData` variable, presented through sample implementation in `MultiCore.sol`, allowing for each `vaultId` to have it's own modules, additional interfaces or metadata. Current sample implementation is suppose to demonstrate usage of `MultiVault.sol` interface for yield aggregator contract. **This repository is not proudction ready**

Inspired by: https://github.com/z0r0z/MultiVault

### Rationale

ERC4626 currently only operates on one underlying token, minting in return one ERC20 shares token, all within one - single - Vault contract, and needs to be redeployed for each new underlying asset with it's separate accounting logic. Often requested functionality is the ability to operate on multiple assets with separate accounting still within single Vault contract. The ERC4626 standard was designed to be inherited and overriden (and such is the expectation) through parent contracts, initialized by other contract or made to use as an instance allowing for quick extending. Despite this underlying flexibility, arguments for a potential standardized extension exist.

Found reccuring patterns hold true across many non-4626 Vaults and can be accomodated with small logical changes to the existing ERC4626 interface while still keeping extension intuitive for developers already working with ERC4626. To that, we demonstrate alpha version of `MultiCore.sol` implementation contract, utilizing our proposed `MultiVault.sol` extension of the ERC4626.

### Changes to ERC4626:

- ERC1155 as shares / lp token for Vault
  - access to batch operations and one time approval
- `totalSupply` of vaultIds (ERC1155 id)
- separate operation logic for each underlying within one `MultiVault`
  - each `vaultId` has it's own underlying and additional data params (`vaultData` is suppose to be very flexible without breaking)
- `create(ERC20 asset)` function to add new vault within core vault contract
- `struct Vault` data structure to hold vital information for `vaultId` (Vault)
  - `ERC20 asset` underlying token for `vaultId`
  - `uint256 totalSupply` total supply of *shares* for `vaultId`. can be left at 0 if not used by implementation.
  - `bytes vaultData` additional data held for `vaultId`, e.g interface of contract for use inside of `afterDeposit()`. Or, any other value. Idea is to map additional logic, implemented by inheriting contract to `vaultId` of `MultiVault`. for clarity, it should decode to single variable and implementer should take care of providing appropriate getters.

_Disclaimer: Exploratory work and designs. Interface standarization is work in progress_

## Common Patterns

Three reccuring patterns for all currently researched multiVaults, warranting one common interface:

1. Reccuring `uint256 indexOfAssets` variable for any sort of id tracking (here, totalSupply of ERC1155 ids). True for underlying assets, shares, supplies & balances or even whole Vaults (ERC1155 MultiVault)
2. Reccuring pattern of addition of another token interface through initialization in existing contract - `create()` function
3. Reccuring pattern of creation of separate accounting calculations for different types of assets/shares. MultiVault preserves original function on ERC4626 standard Vault, namley - managmend of assets. With MultiVault it's now possible to manage all of those assets within one contract.


## Sample Implementation

`MultiCore.sol` is an example implementation of inherited `MultiVault.sol` extension. It serves as a scaffold for multiple assets strategy manager contract (uff...). Accepts multiple underlying tokens and can route to multiple _Strategy_ contracts (In sample implementation this are ERC4626 Vaults, free to be changed to Yearn-like `BaseStrategy`). It centralizes accounting and holds yield bearing assets under managment, effectivley becoming a MetaVault (Vault of Vaults).

Features:

- Multiple underlying tokens accepted
- Holds all LP position inside of one ERC1155 token
  - Access to batch operations
  - Index-like token for basket of shares
- Manage multiple yield generating strategies for each vaultId
- WIP: exchangeRate between MultiVault managed LP-shares

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
