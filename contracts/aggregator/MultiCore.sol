// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {MultiVault} from "../MultiVault.sol";
import {IERC4626} from "../interface/IERC4626.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

// import "hardhat/console.sol";

/// @notice MultiVault is an extension of the ERC4626, Tokenized Vault Standard
/// Allows additional underlying tokens to be managed by one Vault contract
/// Strategy logic for each underlying is expected to be implemented by child contract
/// Sample implementation: MetaVaults - Yield Bearing Asset Manager
contract MockMultiVault is MultiVault {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /// @notice vaultStrategy counter. Unique for each. Maps to vaultId when set()
    uint256 public strategyId;

    /// @notice mapped to vaultId indirectly, yield generating strategy (ERC4626 here)
    mapping(uint256 => IERC4626) public vaultStrategy;

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
                            STRATEGY MANAGMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Create new underlying token for MultiVault
    /// @param asset address of new ERC20 underlying
    function create(ERC20 asset) public override Authorized returns (uint256 id) {
        id = super.create(asset);
    }

    /// @notice Add strategy to the multiVault. Here, ERC4626 standard yield bearing Vault
    /// @param strategy address of ERC4626 strategy to which underlying will be moved
    function set(IERC4626 strategy) public Authorized {
        ++strategyId;
        vaultStrategy[strategyId] = strategy;
    }

    /// @notice Activate strategyId for vaultId. Indirect mapping between stratId and vaultId.
    /// @dev Activate only if no funds require moving from the old Strategy. If they do, call move() first!
    /// @param vaultId vaultId for which strategy is activated
    /// @param stratId id of strategy for vault
    function activate(uint256 vaultId, uint256 stratId) public Authorized {
        vaults[vaultId].vaultData = abi.encode(vaultStrategy[stratId]);
        vaults[vaultId].asset.approve(address(vaultStrategy[stratId]), type(uint256).max);
    }

    /// @notice Move funds from one Strategy to the other
    /// @param vaultId read current Strategy set for this vaultId and withdraw from to this contract
    /// @param newStrat activate new Strategy, set earlier and deposit to it (underlying must match!)
    function move(uint256 vaultId, uint256 newStrat) public Authorized {
        uint256 stratBalance = totalAssets(vaultId);
        currentStrategy(vaultId).withdraw(stratBalance, address(this), address(this));
        activate(vaultId, newStrat);
        currentStrategy(vaultId).deposit(stratBalance, address(this));
    }

    /// @notice Check what strategy is active for vaultId
    function currentStrategy(uint256 vaultId) public view returns (IERC4626) {
        return abi.decode(vaults[vaultId].vaultData, (IERC4626));
    }

    /*///////////////////////////////////////////////////////////////
                           METAVAULTS ROUTING
    //////////////////////////////////////////////////////////////*/

    /// @dev WIP: Could be used for re-adjusting multiple Strategies positions in conjuction with Router
    function batchDepositTo(uint256[] memory vaultIds0, uint256[] memory assets0) internal {}

    function batchWithdrawFrom(uint256[] memory vaultIds0, uint256[] memory assets0) internal {}

    function routeTo(uint256 from, uint256 fAsset, uint256 to, uint256 tAsset) internal {}

    function routeFrom(uint256 from, uint256 fAsset, uint256 to, uint256 tAsset) internal {}

    /// @notice After owner deposits underlying, underlying is moved to one of existing Strategies
    function afterDeposit(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        currentStrategy(vaultId).deposit(assets, address(this));
    }

    /// @notice After owner calls withdraw, underlying is withdraw from the current Strategy and sent to this contract
    /// @dev actual redemption happens in MultiVault
    function beforeWithdraw(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        currentStrategy(vaultId).withdraw(assets, address(this), address(this));
    }

    /*///////////////////////////////////////////////////////////////
                       MULTIVAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Total amount of the underlying asset that is “managed” by vaultId.
    /// @dev MultiVault manages shares of 3rd party Vaults, for accepted asset underlying from depositors.
    /// previewReedem works because MultiVault is an owner of *Strategy* !shares!
    /// and owner of MultiVault shares is expecting to get underlying *accrued* value (deposit+yield)
    function totalAssets(uint256 vaultId) public view override returns (uint256) {
        IERC4626 strategy = currentStrategy(vaultId);
        uint256 shares = strategy.balanceOf(address(this));
        return strategy.previewRedeem(shares); // convert shares to AUM by MultiVault
    }

    function convertToShares(uint256 vaultId, uint256 assets) public view override returns (uint256) {
        uint256 supply = currentStrategy(vaultId).totalSupply();
        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets(vaultId));
    }

    function convertToAssets(uint256 vaultId, uint256 shares) public view override returns (uint256) {
        uint256 supply = currentStrategy(vaultId).totalSupply();
        return supply == 0 ? shares : shares.mulDivDown(totalAssets(vaultId), supply);
    }

    function previewDeposit(uint256 vaultId, uint256 assets) public view override returns (uint256) {
        return convertToShares(vaultId, assets);
    }

    function previewMint(uint256 vaultId, uint256 shares) public view override returns (uint256) {
        uint256 supply = currentStrategy(vaultId).totalSupply();
        return supply == 0 ? shares : shares.mulDivUp(totalAssets(vaultId), supply);
    }

    function previewWithdraw(uint256 vaultId, uint256 assets) public view override returns (uint256) {
        uint256 supply = currentStrategy(vaultId).totalSupply();
        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets(vaultId));
    }

    function previewRedeem(uint256 vaultId, uint256 shares) public view override returns (uint256) {
        return convertToAssets(vaultId, shares);
    }

    /*//////////////////////////////////////////////////////////////
                                OTHER
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 vaultId) public view override returns (string memory) {
        return "https://show.metadata.for.vaultId/vaultId";
    }
}
