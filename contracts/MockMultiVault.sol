// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {MultiVault} from "./MultiVault.sol";

/// @notice MultiVault is an extension of the ERC4626, Tokenized Vault Standard
/// Storage of multiple separate ERC4626 Vaults functionality inside of the MultiCore
/// Allows custom modules, interfaces or metadata for Vault
contract MockMultiVault is MultiVault {

    /// @notice Init first vault. Not neccessary as contract is abstract, but good practice.
    constructor(ERC20 asset, bytes memory vaultData) {
        create(asset, vaultData);
    }
    
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


}
