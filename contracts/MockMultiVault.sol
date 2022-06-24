// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {MultiVault} from "./MultiVault.sol";
import { xERC4626 } from "./mock/xERC4626/xERC4626.sol";

/// @notice MultiVault is an extension of the ERC4626, Tokenized Vault Standard
/// Storage of multiple separate ERC4626 Vaults functionality inside of the MultiCore
/// Allows custom modules, interfaces or metadata for Vault
contract MockMultiVault is MultiVault {

    /// @notice Maps to vaultId
    mapping(uint256 => xERC4626) public vaultData;

    /// @notice Vote for approving Vault
    address public governance;

    /// @notice Reward Vault interface
    /// With this, MultiVault can mint and auto-restake
    /// Different type of rewards for same underlying now possible
    // xERC4626 public rewardVault;

    struct Data {
        string uri;
        address rewardsToken;
        uint256 rewardsCycle;
    }

    modifier onlyGov {
        require(msg.sender == governance, "dao");
        _;
    }

    constructor(address gov) {
        governance = gov;
    }

    /*///////////////////////////////////////////////////////////////
                        MULTIVAULT INTERFACE LOGIC
    //////////////////////////////////////////////////////////////*/

    function create(ERC20 asset) public override onlyGov returns (uint256 id) {
        id = super.create(asset);
    }

    function setRewards(uint256 vaultId, xERC4626 rewards) public onlyGov {
        vaultData[vaultId] = rewards;
    }

    /// @notice potential for being included inside of Vault struct in MultiVault
    /// Reason 1: Easy to accidentally overrwrite, should be set in one place
    /// Reason 2: Requires additional functions to be deduced outside of implementation
    // function setData(uint256 vaultId, string memory _uri, address rewardsToken, uint256 rewardsCycle) public onlyGov {
    //     vaultData[vaultId].uri = _uri;
    //     vaultData[vaultId].rewardsToken = rewardsToken;
    //     vaultData[vaultId].rewardsCycle = rewardsCycle;
    // }   

    /// @notice Shows balance of given vaultId. Same as standard ERC4626 but with selector.
    /// @dev Suggested minimal implementation
    function totalAssets(uint256 vaultId) public view override returns (uint256) {
        return vaults[vaultId].asset.balanceOf(address(this));
    }

    /// @notice Example implementation with URI metadata decoded from created vaultData.
    /// @dev Suggested implementation. Demonstrates utility of bytes vaultData variable.
    function uri(uint256 vaultId) public view override returns (string memory) {
        return "0x";
    }

    /// @notice Visbility getter for vaultData variable across multiple Vaults
    /// SHOULD be implemented by deployer, but return types can differ so hard to enforce on interface level
    // function showVaultData(uint256 vaultId) internal view returns (Data memory d) {
    //     return vaultData[vaultId];
    // }

    function afterDeposit(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        xERC4626 rewards = vaultData[vaultId];
        // rewards.deposit(); // maybe plug-in Strategy works better here (similar to SuperForm too)
    }


}
