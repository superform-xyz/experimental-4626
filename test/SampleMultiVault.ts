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

    const SampleMultiVaultFactory = await ethers.getContractFactory("SampleMultiVault");
    SampleMultiVault = await SampleMultiVaultFactory.deploy();
    await SampleMultiVault.deployed();

    /// We create first vaultId on runtime, create now can be thoroughly tested elsewhere
    // await SampleMultiVault.create(ERC20.address, vaultData);

    await ERC20.mint(deployer.address, getBigNumber(1000));
    await ERC20.approve(SampleMultiVault.address, getBigNumber(1000));
    await SampleMultiVault.create(ERC20.address, vaultData);

  });

  describe("Base Tests", async () => {
    it("deposit() vaultId 1", async () => {
      await SampleMultiVault.deposit(1, getBigNumber(100), deployer.address);
    });

    it("previewDeposit()", async () => {
      const val = await SampleMultiVault.previewDeposit(1, getBigNumber(100));
      // console.log("previewDeposit val", val);
    });

    it("mint() vaultId 1", async () => {
      await SampleMultiVault.mint(1, getBigNumber(100), deployer.address);
    });

    it("previewMint()", async () => {
      const val = await SampleMultiVault.previewMint(1, getBigNumber(100));
      // console.log("previewMint val", val);
    });

    it("withdraw() vaultId 1", async () => {
      await SampleMultiVault.withdraw(
        1,
        getBigNumber(100),
        deployer.address,
        deployer.address
      );
    });

    it("previewWithdraw()", async () => {
      const val = await SampleMultiVault.previewWithdraw(1, getBigNumber(100));
      // console.log("previewWithdraw val", val);
    });

    it("redeem() vaultId 1", async () => {
      const shares = await SampleMultiVault.balanceOf(deployer.address, 1);
      // console.log("remaining lp tokens", shares);
      await SampleMultiVault.redeem(1, shares, deployer.address, deployer.address);
    });

    it("previewRedeem()", async () => {
      const val = await SampleMultiVault.previewRedeem(1, getBigNumber(100));
      // console.log("previewRedeem val", val);
    });
  });

  // describe("vaultData Testing", async () => {
  //   it("printData()", async () => {
  //     expect(await SampleMultiVault.previewData(1)).to.deep.equal(["https://erc4626.info", ERC20.address]);
  //   });

  //   it("uri()", async () => {
  //     expect(await SampleMultiVault.uri(1)).to.be.equal("https://erc4626.info");
  //   });

  //   it("useData()", async () => {
  //     await SampleMultiVault.callData(1);
  //   });
  // });
});
