// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {MultiVault} from "./MultiVault.sol";

/// Sample interface extending ERC20. Implementation specific
import {MockInterface} from "./mock/MockInterface.sol";

/// @notice MultiVault is an extension of the ERC4626, Tokenized Vault Standard
/// Allows for storage of multiple separate ERC4626 assets with their own accounting and logic
/// Allows custom modules, interfaces or metadata for each tracked id
contract MultiCore is MultiVault {

    /*///////////////////////////////////////////////////////////////
                        USING MULTIVAULT INTERFACE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Example implementation with URI metadata decoded from created vaultData.
    function uri(uint256 vaultId) public view override returns (string memory) {
        (string memory _uri, ) = abi.decode(vaults[vaultId].vaultData, (string, address));
        return _uri;
    }

    /// @notice Shows balance of given vaultId. Same as standard ERC4626 but with selector.
    /// @dev Only sample implementation. In interface still virtual.
    function totalAssets(uint256 vaultId) public view override returns (uint256) {
        return vaults[vaultId].asset.balanceOf(address(this));
    }

    /// @notice Create new Vault
    /// @param asset underlying token of new vault
    /// @param vaultData any encoded additional data for vault eg. metadata uri string
    /// @dev encoded data can be anything, but implementations of other functions will need to follow defined data structure
    function create(ERC20 asset, bytes memory vaultData) public override returns (uint256) {
        return super.create(asset, vaultData);
    }

    /// @dev MUST return bytes data for internal use of MultiVault contract. Decode data in child.
    function previewData(uint256 vaultId) public view override returns (bytes memory) {
        return super.previewData(vaultId);
    }

    /// @notice Hook, same as ERC4626
    /// @dev Can/should act on vaultData values
    function beforeWithdraw(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        /// @dev Suggested usage of vaultData
        bytes memory vaultData = previewData(vaultId);
    }

    /// @notice Hook, same as ERC4626
    /// @dev Can/should act on vaultData values
    function afterDeposit(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        bytes memory vaultData = previewData(vaultId);
    }

    /*///////////////////////////////////////////////////////////////
                        PARENT CONTRACT FUNCTIONS
               Utilizing inherited MultiVault functionality
    //////////////////////////////////////////////////////////////*/

    /// @notice Call vaultData earlier specified interface
    function useData(uint256 vaultId) public {
        (, address token) = readData((vaultId));
        MockInterface _token = MockInterface(token);
        _token.mint(address(this), 1e18);
    }

    /// @notice Change vaultData for given vaultId
    function setData(uint256 vaultId, bytes memory vaultData) public {
        vaults[vaultId].vaultData = vaultData;
    }

    /// @dev MultiVault should operate only on bytes data. Here, function is provided for readability
    function readData(uint256 vaultId) public view returns (string memory, address) {
        return abi.decode(vaults[vaultId].vaultData, (string, address));
    }
}
