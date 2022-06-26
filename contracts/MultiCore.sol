// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {MultiVault} from "./MultiVault.sol";
import { IERC4626 } from "./interface/IERC4626.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

import "hardhat/console.sol";

/// @notice MultiVault is an extension of the ERC4626, Tokenized Vault Standard
/// Allows additional underlying tokens to be managed by one Vault contract
/// Strategy logic for each underlying is expected to be implemented per need
/// MetaVaults - Yield Bearing Asset Manager
/// Other impl: Strategy Manager (change vaultStrategy for anything, e.g Yearn BaseStrategy)
contract MockMultiVault is MultiVault {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /// @notice Vault id tracking and total supply of different Vaults
    uint256 public strategyId;

    /// @notice Maps to vaultId
    mapping(uint256 => IERC4626) public vaultStrategy;

    /// @notice Vote for approving Vault
    address public governance;

    modifier onlyGov {
        require(msg.sender == governance, "dao");
        _;
    }

    constructor(address gov) {
        governance = gov;
    }

    /*///////////////////////////////////////////////////////////////
                            STRATEGY MANAGMENT
    //////////////////////////////////////////////////////////////*/

    function create(ERC20 asset) public override onlyGov returns (uint256 id) {
        id = super.create(asset);
    }

    function set(IERC4626 strategy) public onlyGov {
        ++strategyId;
        vaultStrategy[strategyId] = strategy;
    }

    /// @notice Activate strategyId for vaultId. Indirect mapping between stratId and vaultId.
    function activate(uint256 vaultId, uint256 stratId) public onlyGov {
        vaults[vaultId].vaultData = abi.encode(vaultStrategy[stratId]);
        vaults[vaultId].asset.approve(address(vaultStrategy[stratId]), type(uint256).max);
    }

    function currentStrategy(uint256 vaultId) public view returns (IERC4626) {
        return abi.decode(vaults[vaultId].vaultData, (IERC4626));
    }

    /*///////////////////////////////////////////////////////////////
                           METAVAULTS ROUTING
    //////////////////////////////////////////////////////////////*/

    function afterDeposit(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal override {
        currentStrategy(vaultId).deposit(assets, address(this));
    }

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
    /// @dev Synthethic value. MultiVault manages yield bearing LP, but owner wants asset
    /// @dev previewReedem works because MultiVault is owner of strategy shares 
    /// and owner of MultiVault shares is expecting to get underlying *accrued* value
    function totalAssets(uint256 vaultId) public view override returns (uint256) {
        IERC4626 strategy = currentStrategy(vaultId);
        uint256 shares = strategy.balanceOf(address(this)); // .this holds LP shares of strat
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
                                OTHERS
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 vaultId) public view override returns (string memory) {
        return "https://show.metadata.for.vaultId/vaultId";
    }

} 
