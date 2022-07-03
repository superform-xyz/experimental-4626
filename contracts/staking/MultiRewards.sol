// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {MultiVault} from "../MultiVault.sol";
import {IxERC4626} from "../mock/xERC4626/IxERC4626.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

// import "hardhat/console.sol";

/// @notice MultiVault is an extension of the ERC4626, Tokenized Vault Standard
/// Scenario: We want to set different reward scheme, depending on deposited underlying
/// Ideally, we want to update/change reward schemes based on some mechanism ie. bribing, oracle data, voting
contract MockMultiRewards is MultiVault {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /// @notice vaultStrategy counter. Unique for each. Maps to vaultId when set()
    uint256 public rewardId;

    /// @notice mapped to vaultId indirectly. rewards vault with cyclic reward scheme (xERC4626)
    mapping(uint256 => IxERC4626) public rewardVault;

    /// @notice Access control over new underlying creation
    address public auth;

    modifier Authorized() {
        require(msg.sender == auth, "auth");
        _;
    }
    constructor(address _auth) {
        auth = _auth;
    }

    /*///////////////////////////////////////////////////////////////
                            REWARDS MANAGMENT
    //////////////////////////////////////////////////////////////*/

    function createReward(IxERC4626 reward) public Authorized returns (uint256 id) {
        ERC20 asset = ERC20(reward.asset());
        id = create(asset);
        set(reward, id);
    }

    /// @notice Add strategy to the multiVault. Here, ERC4626 standard yield bearing Vault
    /// @param reward address of IxERC4626 reward to deposit to
    /// @param vaultId for which vaultId reward is set (it will overwrite if set again on existing vaultId)
    function set(IxERC4626 reward, uint256 vaultId) public Authorized {
        ++rewardId;
        rewardVault[rewardId] = reward;
        vaults[vaultId].vaultData = abi.encode(reward);
        vaults[vaultId].asset.approve(address(rewardVault[rewardId]), type(uint256).max);
    }

    /// @notice Create new rewardCycle for the new underlying asset
    /// @param asset address of new ERC20 underlying
    function create(ERC20 asset) public override Authorized returns (uint256 id) {
        id = super.create(asset);
    }

    /// @notice Check currently set Rewards for given vaultId
    function currentRewards(uint256 vaultId) public view returns (IxERC4626) {
        return abi.decode(vaults[vaultId].vaultData, (IxERC4626));
    }

    /*///////////////////////////////////////////////////////////////
                           REWARDS ROUTING
    //////////////////////////////////////////////////////////////*/

    function batchClaim(uint256[] memory vaultIds, uint256[] memory assets) public {}


    /// @notice After owner deposits underlying, underlying is moved to one of existing Strategies
    function afterDeposit(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        currentRewards(vaultId).deposit(assets, address(this));
    }

    /// @notice After owner calls withdraw, underlying is withdraw from the current Strategy and sent to this contract
    function beforeWithdraw(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        currentRewards(vaultId).withdraw(assets, address(this), address(this));
    }

    /*///////////////////////////////////////////////////////////////
                       MULTIVAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Total amount of the underlying asset that is “managed” by vaultId.
    /// @dev Currently this makes MultiRewards vault act like a Router
    function totalAssets(uint256 vaultId) public view override returns (uint256) {
        IxERC4626 rewards = currentRewards(vaultId);
        return rewards.totalAssets();
    }

    function convertToShares(uint256 vaultId, uint256 assets) public view override returns (uint256) {
        return currentRewards(vaultId).convertToShares(assets);
    }

    function convertToAssets(uint256 vaultId, uint256 shares) public view override returns (uint256) {
        return currentRewards(vaultId).convertToAssets(shares);

    }

    function previewDeposit(uint256 vaultId, uint256 assets) public view override returns (uint256) {
        return currentRewards(vaultId).previewDeposit(assets);
    }

    function previewMint(uint256 vaultId, uint256 shares) public view override returns (uint256) {
        return currentRewards(vaultId).previewMint(shares);

    }

    function previewWithdraw(uint256 vaultId, uint256 assets) public view override returns (uint256) {
        return currentRewards(vaultId).previewWithdraw(assets);

    }

    function previewRedeem(uint256 vaultId, uint256 shares) public view override returns (uint256) {
        return currentRewards(vaultId).previewRedeem(shares);

    }

    /*//////////////////////////////////////////////////////////////
                                OTHER
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 vaultId) public view override returns (string memory) {
        return "https://show.metadata.for.vaultId/vaultId";
    }
}
