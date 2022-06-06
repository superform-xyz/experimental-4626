// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@rari-capital/solmate/src/mixins/ERC4626.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

/// @notice EIP-4626 Extended for support of additional ERC20 underlying tokens for Single Vault.
contract MultiUnderlyingVault is ERC20 {
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ERC20 public immutable asset;

    uint256 public indexOfAssets;

    mapping(uint256 => ERC20) public _assets;

    constructor(
        ERC20 asset0,
        ERC20 asset1, /// @dev at least one needs to be initialized
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        asset = asset0;
        _assets[++indexOfAssets] = asset1;
    }

    /*//////////////////////////////////////////////////////////////
                            FUNDING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev adds another deposit token to the Vault accounting
    function create(ERC20 _asset) public virtual returns (uint256 indexOf) {
        indexOf = ++indexOfAssets;
        _assets[indexOfAssets] = _asset;
    }

    function totalAssets() public view virtual returns (uint256 balance) {
        for (uint256 i = 0; i < indexOfAssets; i++) {
            balance += _assets[i].balanceOf(address(this));
        }
    }

    function totalAssetsFunded(uint256 index) public view virtual returns (uint256) {
        return _assets[index].balanceOf(address(this));
    }

    function fund(
        uint256 index,
        uint256 assets,
        address to
    ) public virtual returns (uint256 fundIn) {
        _assets[index].transferFrom(msg.sender, address(this), assets);
        _mint(to, fundIn = previewFund(assets, index));
    }

    function defund(
        uint256 index,
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256 fundOut) {
        fundOut = previewDefund(shares, index);
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);

            if (allowed != type(uint256).max) allowed = allowed - shares;
        }
        _burn(owner, shares);
        _assets[index].transfer(receiver, fundOut);
    }

    /*//////////////////////////////////////////////////////////////
                SPECIAL ACCOUNTING FOR OTHER ASSETS
    //////////////////////////////////////////////////////////////*/
    function previewFund(uint256 assets, uint256 index) public virtual returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssetsFunded(index));
    }

    function previewDefund(uint256 shares, uint256 index) public virtual returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares.mulDivDown(totalAssetsFunded(index), supply);
    }

    function maxFund(address) public virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxDefund(address) public virtual returns (uint256) {
        return type(uint256).max;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.transferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.transferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender); // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowed = allowed - shares;
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.transfer(receiver, assets);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender); // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowed = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.transfer(receiver, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @dev Owner has only 1 type of LP-Share. Index is used down the call chain to select appropriate totalAssets()
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf(owner);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}
