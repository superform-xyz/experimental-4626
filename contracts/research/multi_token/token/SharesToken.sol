// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {Auth, Authority} from "@rari-capital/solmate/src/auth/Auth.sol";

contract SharesToken is ERC20, Auth {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address owner,
        Authority _authority /// @param contract implementing canCall
    ) ERC20(_name, _symbol, _decimals) Auth(owner, _authority) {}

    function mint(address to, uint256 amount) external requiresAuth {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external requiresAuth {
        _burn(from, amount);
    }
}
