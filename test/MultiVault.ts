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
  let MockMultiVault: Contract;
  let ERC20: Contract;
  let ERC4626Vault: Contract;
  let vaultData: any;

  before("deploy multicore and utils", async () => {
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

    const MockMultiVaultFactory = await ethers.getContractFactory("MockMultiVault");
    MockMultiVault = await MockMultiVaultFactory.deploy(ERC20.address, vaultData);
    await MockMultiVault.deployed();

    await ERC20.mint(deployer.address, getBigNumber(1000));
    await ERC20.approve(MockMultiVault.address, getBigNumber(1000));

    /// Create should get another test. We deploy first vault on runtime
    // await MockMultiVault.create(ERC20.address, vaultData);
  });

});
