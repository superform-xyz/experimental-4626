import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { BigNumber, Contract } from "ethers";
import { ethers } from "hardhat";

chai.use(solidity);
const { expect } = chai;

// Defaults to e18 using amount * 10^18
async function getBigNumber(amount: number, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimals));
}

describe("Testing Sample Implementation of MultiVault - Vault Aggregator", async () => {
  let deployer: SignerWithAddress;
  let SampleMultiVault: Contract;
  let ERC20: Contract;
  let ERC4626Vault: Contract;
  let vaultData: any;

  async function showMultiVaultAccounting() {
    const shares = await SampleMultiVault.balanceOf(deployer.address, 1);
    console.log("MultiVault shares in ownership of depositor:", ethers.utils.formatUnits(shares));
    const assetsFromShares = await SampleMultiVault.previewRedeem(1, shares);
    console.log("Preview redemption of MultiVault shares from underlying", ethers.utils.formatUnits(assetsFromShares))
    const assetsTotal = await SampleMultiVault.totalAssets(1);
    console.log("MultiVault totalAssets (4626 LP under mgmt)\n", ethers.utils.formatUnits(assetsTotal))
  }

  before("deploy infra and utils", async () => {
    [deployer] = await ethers.getSigners();

    const ERC20Factory = await ethers.getContractFactory("MockToken");
    ERC20 = await ERC20Factory.deploy("ERC20Token", "ERC20", 18);
    await ERC20.deployed();

    const ERC4626VaultFactory = await ethers.getContractFactory("SimpleVault");
    ERC4626Vault = await ERC4626VaultFactory.deploy(
      ERC20.address,
      "TestVault",
      "ERC4626"
    );
    await ERC4626Vault.deployed();
    vaultData = ethers.utils.defaultAbiCoder.encode(
      ["string", "address"],
      ["https://erc4626.info", ERC20.address]
    );

    const SampleMultiVaultFactory = await ethers.getContractFactory("MockMultiVault");
    SampleMultiVault = await SampleMultiVaultFactory.deploy(deployer.address);
    await SampleMultiVault.deployed();

    await ERC20.mint(deployer.address, getBigNumber(1000));
    await ERC20.approve(SampleMultiVault.address, getBigNumber(1000));
    await ERC20.transfer(ERC4626Vault.address, getBigNumber(10)); /// simulate yield

    await SampleMultiVault.create(ERC20.address);
    await SampleMultiVault.set(ERC4626Vault.address);
    await SampleMultiVault.activate(1, 1);

  });

  describe("Base Tests", async () => {
    it("deposit() vaultId 1", async () => {
      const expectedShares = await SampleMultiVault.previewDeposit(1, getBigNumber(100));
      await SampleMultiVault.deposit(1, getBigNumber(100), deployer.address);
      const balanceOfShares = await SampleMultiVault.balanceOf(deployer.address, 1);
      expect(expectedShares).to.be.equal(balanceOfShares);
      console.log("State of the Vault after deposit()\n");
      await showMultiVaultAccounting();
    });


    it("mint() vaultId 1", async () => {
      const expectedShares = await SampleMultiVault.previewMint(1, getBigNumber(100))
      const balanceOfSharesBefore = await SampleMultiVault.balanceOf(deployer.address, 1);
      await SampleMultiVault.mint(1, expectedShares, deployer.address);
      const balanceOfSharesAfter = await SampleMultiVault.balanceOf(deployer.address, 1);
      expect(balanceOfSharesAfter).to.be.equal(balanceOfSharesBefore.add(expectedShares));
      console.log("State of the Vault after mint()\n")
       await showMultiVaultAccounting();
    });
  
    it("redeem() all from vaultId 1", async () => {
      const balanceOfShares = await SampleMultiVault.balanceOf(deployer.address, 1);
      await SampleMultiVault.redeem(1, balanceOfShares, deployer.address, deployer.address);
      const balanceOfSharesAfter = await SampleMultiVault.balanceOf(deployer.address, 1);
      expect(balanceOfSharesAfter).to.be.equal(BigNumber.from(0));
      console.log("State of the Vault after redeem()\n")
      await showMultiVaultAccounting();
    });

    it("withdraw() half of the assets from vaultId 1", async () => {
      const expectedShares = await SampleMultiVault.previewDeposit(1, getBigNumber(100));
      await SampleMultiVault.deposit(1, getBigNumber(100), deployer.address);
      const balanceOfShares = await SampleMultiVault.balanceOf(deployer.address, 1);
      expect(expectedShares).to.be.equal(balanceOfShares);
      const exchangedShares = await SampleMultiVault.previewRedeem(1, getBigNumber(50));
      await SampleMultiVault.withdraw(
        1,
        getBigNumber(50),
        deployer.address,
        deployer.address
      );
      const balanceOfSharesAfter = await SampleMultiVault.balanceOf(deployer.address, 1);
      expect(balanceOfSharesAfter).to.be.equal(balanceOfShares.sub(exchangedShares));
      console.log("State of the Vault after withdraw()\n")
      await showMultiVaultAccounting();
    });

    it("previewMint()", async () => {
      const val = await SampleMultiVault.previewMint(1, getBigNumber(100));
      // console.log("previewMint val", val);
    });

    it("previewDeposit()", async () => {
      const val = await SampleMultiVault.previewDeposit(1, getBigNumber(100));
      // console.log("previewDeposit val", val);
    });

    it("previewWithdraw()", async () => {
      const val = await SampleMultiVault.previewWithdraw(1, getBigNumber(100));
      // console.log("previewWithdraw val", val);
    });

    it("previewRedeem()", async () => {
      const val = await SampleMultiVault.previewRedeem(1, getBigNumber(100));
      // console.log("previewRedeem val", ethers.utils.formatUnits(val));
    });
  });

  describe("vaultData Testing", async () => {

    it("gasTest single deposit()", async () => {
      await ERC20.approve(ERC4626Vault.address, getBigNumber(100))
      await ERC4626Vault.deposit(getBigNumber(100), deployer.address);
      console.log("Compare direct deposit() to the vault:\n")
      await showMultiVaultAccounting();
      const expectedShares = await ERC4626Vault.previewMint(getBigNumber(100))
      await SampleMultiVault.mint(1, expectedShares, deployer.address);
      console.log("Compare direct mint() to the vault:\n")
      await showMultiVaultAccounting();
    });

  });

});
