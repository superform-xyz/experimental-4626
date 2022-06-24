// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {MultiVault} from "../MultiVault.sol";

/// Sample interface extending ERC20. Implementation specific.
import {MockInterface} from "../mock/MockInterface.sol";

/// @notice MultiVault is an extension of the ERC4626, Tokenized Vault Standard
/// Storage of multiple separate ERC4626 Vaults functionality inside of the MultiCore
/// Allows custom modules, interfaces or metadata for Vault
contract SampleMultiVault is MultiVault {
    
    /*///////////////////////////////////////////////////////////////
                        MULTIVAULT INTERFACE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Shows balance of given vaultId. Same as standard ERC4626 but with selector.
    /// @dev Suggested minimal implementation
    function totalAssets(uint256 vaultId) public view override returns (uint256) {
        return vaults[vaultId].asset.balanceOf(address(this));
    }

    /// @notice Example implementation with URI metadata decoded from created vaultData.
    /// @dev Suggested implementation. Demonstrates utility of bytes vaultData variable.
    function uri(uint256 vaultId) public view override returns (string memory) {
        (string memory _uri, ) = printData(vaultId);
        return _uri;
    }

    /// @notice Visbility getter for vaultData variable across multiple Vaults
    /// SHOULD be implemented by deployer, but return types can differ so hard to enforce on interface level
    function printData(uint256 vaultId) internal view returns (string memory, address) {
        Vault memory v = previewData(vaultId);
        return abi.decode(v.vaultData, (string, address));
    }

    function afterDeposit(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        Vault memory v = previewData(vaultId);  
    }

    /*///////////////////////////////////////////////////////////////
                        PARENT CONTRACT FUNCTIONS
               Utilizing inherited MultiVault functionality
    //////////////////////////////////////////////////////////////*/

    /// @notice Call vaultData earlier specified interface
    function callData(uint256 vaultId) public {
        (, address token) = printData((vaultId));
        MockInterface _token = MockInterface(token);
        _token.mint(address(this), 1e18);
    }

}
