// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ERC4626} from "@rari-capital/solmate/src/mixins/ERC4626.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

import "hardhat/console.sol";

/// @notice Standard ERC4626 Vault for testing with MultiVault
contract SimpleVault is ERC4626 {
    constructor(
        ERC20 asset,
        string memory name,
        string memory symbol
    ) ERC4626(asset, name, symbol) {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
