// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Customized ERC20 interface for testing with vaultData on MultiVault
interface MockInterface is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
