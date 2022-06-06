// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.1;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SharesToken} from "./token/SharesToken.sol";
import {Auth, Authority} from "@rari-capital/solmate/src/auth/Auth.sol";
import {ERC4626} from "@rari-capital/solmate/src/mixins/ERC4626.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

/// @notice Introduce calculations for two or more separate ERC20 tokens asset in one Vault.
contract MultiUnderlyingVault is ERC20, Auth {
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

    /// @dev Assumption: Contract should use different accounting for specific type of deposit
    mapping(SharesToken => uint256) public fundingSupply;

    /// @dev Special Token. E.g, restricted by Access Control and minted as additional Vault share (LP token).
    mapping(uint256 => SharesToken) public _assets;

    constructor(
        ERC20 _asset,
        SharesToken sharesToken, /// @param *funding* token. useful if Vault needs separate exchange rate for one of assets.
        string memory name,
        string memory symbol,
        address owner,
        Authority _authority /// @param contract implementing canCall
    ) ERC20(name, symbol) Auth(owner, _authority) {
        asset = _asset;
        _assets[++indexOfAssets] = sharesToken;
    }

    /*//////////////////////////////////////////////////////////////
                            FUNDING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev adds another deposit token to the Vault accounting
    function create(string memory _name, string memory _symbol) public virtual requiresAuth returns (uint256 indexOf) {
        indexOf = ++indexOfAssets;
        _assets[indexOfAssets] = new SharesToken(_name, _symbol, 18, owner, authority);
    }

    function totalAssets() public view virtual returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @dev Returns totalAssets under Vault managment, other than core underlying
    /// E.g Volatile tokens funding for Stablecoins or different tokens utilized for different strategy
    function totalAssetsFunded(uint256 index) public view virtual returns (uint256) {
        return fundingSupply[_assets[index]];
    }

    function fund(
        uint256 index,
        uint256 assets,
        address to
    ) public virtual returns (uint256 fundIn) {
        asset.transferFrom(msg.sender, address(this), assets);
        SharesToken token = _assets[index];
        fundingSupply[token] += assets;
        token.mint(to, fundIn = previewFund(assets, index));
    }

    function defund(
        uint256 index,
        uint256 shares,
        address receiver,
        address sender
    ) public virtual returns (uint256 fundOut) {
        fundOut = previewDefund(shares, index);
        if (msg.sender != sender) {
            uint256 allowed = _assets[index].allowance(sender, msg.sender);

            if (allowed != type(uint256).max) allowed = allowed - shares;
        }
        SharesToken token = _assets[index];
        fundingSupply[token] -= fundOut;
        token.burn(owner, shares);
        asset.transfer(receiver, fundOut);
    }

    /// @notice Returns different accounting result for specific type of LP-Share
    /// Example: Underlying asset is supposed to be stable. This can be achieved through
    /// overcollaterized funding, where Underlying totalAssets() will be bigger than Underlying deposited().
    /// Depositors through funding mechanism are expected to receive some premium. Premium logic
    /// should be implemented in this set of functions.
    function previewFund(uint256 assets, uint256 index) public virtual returns (uint256) {
        uint256 supply = _assets[index].totalSupply();
        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssetsFunded(index));
    }

    function previewDefund(uint256 shares, uint256 index) public virtual returns (uint256) {
        uint256 supply = _assets[index].totalSupply();
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
        address sender
    ) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != sender) {
            uint256 allowed = allowance(sender, msg.sender); // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowed = allowed - shares;
        }

        beforeWithdraw(assets, shares);

        _burn(sender, shares);

        emit Withdraw(msg.sender, receiver, sender, assets, shares);

        asset.transfer(receiver, assets);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address sender
    ) public virtual returns (uint256 assets) {
        if (msg.sender != sender) {
            uint256 allowed = allowance(sender, msg.sender); // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowed = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(sender, shares);

        emit Withdraw(msg.sender, receiver, sender, assets, shares);

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

    function maxWithdraw(address _owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf(_owner));
    }

    function maxRedeem(address _owner) public view virtual returns (uint256) {
        return balanceOf(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}
