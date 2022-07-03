// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ERC1155} from "@rari-capital/solmate/src/tokens/ERC1155.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

/// @notice Prototype of ERC4626 MultiVault extension
abstract contract MultiVault is ERC1155 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, ERC20 indexed asset, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    );

    event Create(ERC20 indexed asset, uint256 id);

    /*///////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Vault id tracking and total supply of different Vaults
    uint256 public totalSupply;

    /// @notice Multiple vault underlying assets
    mapping(uint256 => Vault) public vaults;

    /// @notice Vault Data (Optional)
    /// @param asset underlying token of this vaultId / REQUIRED
    /// @param totalSupply shares tracking for each vaultId / OPTIONAL
    /// @param vaultData experimental - additional data for vaultId / OPTIONAL
    /// @dev vaultData is useful when additional logic for vaultId is needed.
    /// @dev ensures that whatever is vaultData, it maps to Vault, allowing to extend it further.
    /// @dev If only struct could be overriden[1] (even if mapping as public state var vaults is)
    /// @dev vaultData wouldn't be needed. inheriting contract would define types.
    /// @dev however, even then, we need reliable and stable implementation of Vault struct
    /// @dev totalSupply and vaultData provide all extended operability 
    /// @dev at the same time being optional - keeping interface consitent
    /// @dev downside is vaultData actual value is left to be deduced
    /// @dev if implementer isn't dilligent. with current solidity limitations[1]
    /// @dev best to enocde vaultData with only ONE variable for clarity of decode
    struct Vault {
        ERC20 asset;
        uint256 totalSupply;
        bytes vaultData;
    }

    /// @notice [1] We currently can't override 
    /// https://github.com/ethereum/solidity/issues/6337#issuecomment-1140000320
    /// https://github.com/ethereum/solidity/issues/11826#issuecomment-902835510
    /// https://github.com/ethereum/solidity/issues/8489#issuecomment-598685028

    /*///////////////////////////////////////////////////////////////
                            MULTIVAULT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Create new Vault
    /// @param asset new underlying token for vaultId
    function create(ERC20 asset) public virtual returns (uint256 id) {
        unchecked {
            id = ++totalSupply;
        }

        vaults[id].asset = asset;

        emit Create(asset, id);
    }

    /// @notice Optional getter
    function getVault(uint256 vaultId) public virtual returns (Vault memory) {
        return abi.decode(vaults[vaultId].vaultData, (Vault));
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(
        uint256 vaultId,
        uint256 assets,
        address receiver
    ) public returns (uint256 shares) {
        Vault memory vault = vaults[vaultId];

        require((shares = previewDeposit(vaultId, assets)) != 0, "ZERO_SHARES");

        vault.asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, vaultId, shares, "");

        // vault.totalSupply += shares;

        emit Deposit(msg.sender, receiver, vault.asset, assets, shares);

        afterDeposit(vaultId, assets, shares);
    }

    function mint(
        uint256 vaultId,
        uint256 shares,
        address receiver
    ) public returns (uint256 assets) {
        Vault memory vault = vaults[vaultId];

        assets = previewMint(vaultId, shares);

        vault.asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, vaultId, shares, "");

        // vault.totalSupply += shares;
        
        emit Deposit(msg.sender, receiver, vault.asset, assets, shares);

        afterDeposit(vaultId, assets, shares);
    }

    function withdraw(
        uint256 vaultId,
        uint256 assets,
        address receiver,
        address owner
    ) public returns (uint256 shares) {
        Vault memory vault = vaults[vaultId];

        shares = previewWithdraw(vaultId, assets);

        if (msg.sender != owner) require(isApprovedForAll[owner][msg.sender], "NOT_OPERATOR");

        beforeWithdraw(vaultId, assets, shares);

        _burn(owner, vaultId, shares);

        // vault.totalSupply -= shares;

        emit Withdraw(msg.sender, receiver, owner, vaultId, assets, shares);

        vault.asset.safeTransfer(receiver, assets);
    }

    function redeem(
        uint256 vaultId,
        uint256 shares,
        address receiver,
        address owner
    ) public returns (uint256 assets) {
        if (msg.sender != owner) require(isApprovedForAll[owner][msg.sender], "NOT_OPERATOR");
        require((assets = previewRedeem(vaultId, shares)) != 0, "ZERO_ASSETS");

        Vault memory vault = vaults[vaultId];
        beforeWithdraw(vaultId, assets, shares);

        _burn(owner, vaultId, shares);

        // vaults[vaultId].totalSupply -= shares;

        emit Withdraw(msg.sender, receiver, owner, vaultId, assets, shares);

        vault.asset.safeTransfer(receiver, assets);
    }

    /*///////////////////////////////////////////////////////////////
                           ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets(uint256 vaultId) public view virtual returns (uint256) {
        return vaults[vaultId].asset.balanceOf(address(this));
    }

    function convertToShares(uint256 vaultId, uint256 assets) public view virtual returns (uint256) {

        uint256 supply = vaults[vaultId].totalSupply;

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets(vaultId));
    }

    function convertToAssets(uint256 vaultId, uint256 shares) public view virtual returns (uint256) {
        uint256 supply = vaults[vaultId].totalSupply;

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(vaultId), supply);
    }

    function previewDeposit(uint256 vaultId, uint256 assets) public view virtual returns (uint256) {
        return convertToShares(vaultId, assets);
    }

    function previewMint(uint256 vaultId, uint256 shares) public view virtual returns (uint256) {
        uint256 supply = vaults[vaultId].totalSupply;

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(vaultId), supply);
    }

    function previewWithdraw(uint256 vaultId, uint256 assets) public view virtual returns (uint256) {
        uint256 supply = vaults[vaultId].totalSupply;

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets(vaultId));
    }

    function previewRedeem(uint256 vaultId, uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(vaultId, shares);
    }

    /*///////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(uint256 vaultId, address owner) public view returns (uint256) {
        return convertToAssets(vaultId, balanceOf[owner][vaultId]);
    }

    function maxRedeem(uint256 vaultId, address owner) public view returns (uint256) {
        return balanceOf[owner][vaultId];
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal virtual {}

    function afterDeposit(
        uint256 vaultId,
        uint256 assets,
        uint256 shares
    ) internal virtual {}
}
