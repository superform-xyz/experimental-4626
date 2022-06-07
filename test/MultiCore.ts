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

describe("MultiVault extension", async () => {
  let deployer: SignerWithAddress;
  let MultiCore: Contract;
  let ERC20: Contract;
  let ERC4626Vault: Contract;
  let vaultData: any;
  // let Flywheel: Contract;

  before("deploy multicore and utils", async () => {
    [deployer] = await ethers.getSigners();

    const MultiCoreFactory = await ethers.getContractFactory("MultiCore");
    MultiCore = await MultiCoreFactory.deploy();
    await MultiCore.deployed();

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

    await ERC20.mint(deployer.address, getBigNumber(1000));
    await ERC20.approve(MultiCore.address, getBigNumber(1000));

    vaultData = ethers.utils.defaultAbiCoder.encode(
      ["string", "address"],
      ["https://erc4626.info", ERC20.address]
    );

    await MultiCore.create(ERC20.address, vaultData);
  });

  describe("Base Tests", async () => {
    it("deposit() vaultId 1", async () => {
      await MultiCore.deposit(1, getBigNumber(100), deployer.address);
    });

    it("previewDeposit()", async () => {
      const val = await MultiCore.previewDeposit(1, getBigNumber(100));
      // console.log("previewDeposit val", val);
    });

    it("mint() vaultId 1", async () => {
      await MultiCore.mint(1, getBigNumber(100), deployer.address);
    });

    it("previewMint()", async () => {
      const val = await MultiCore.previewMint(1, getBigNumber(100));
      // console.log("previewMint val", val);
    });

    it("withdraw() vaultId 1", async () => {
      await MultiCore.withdraw(
        1,
        getBigNumber(100),
        deployer.address,
        deployer.address
      );
    });

    it("previewWithdraw()", async () => {
      const val = await MultiCore.previewWithdraw(1, getBigNumber(100));
      // console.log("previewWithdraw val", val);
    });

    it("redeem() vaultId 1", async () => {
      const shares = await MultiCore.balanceOf(deployer.address, 1);
      // console.log("remaining lp tokens", shares);
      await MultiCore.redeem(1, shares, deployer.address, deployer.address);
    });

    it("previewRedeem()", async () => {
      const val = await MultiCore.previewRedeem(1, getBigNumber(100));
      // console.log("previewRedeem val", val);
    });
  });

  describe("vaultData Testing", async () => {
    it("previewData()", async () => {
      expect(await MultiCore.previewData(1)).to.be.equal(vaultData);
    });

    it("uri()", async () => {
      expect(await MultiCore.uri(1)).to.be.equal("https://erc4626.info");
    });

    it("useData()", async () => {
      await MultiCore.useData(1);
    });
  });
});
