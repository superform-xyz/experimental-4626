// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ERC1155} from "@rari-capital/solmate/src/tokens/ERC1155.sol";
import {ERC4626} from "@rari-capital/solmate/src/mixins/ERC4626.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

/// @notice Prototype of ERC4626 MultiVault extension
abstract contract TokenSplitter {}