import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.create();

describe("Lock", function () {
  async function deployLockFixture() {
    const [owner, alice] = await ethers.getSigners();
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const unlockTime = currentTimestamp + 30 * 24 * 60 * 60;
    const lock = await ethers.deployContract("Lock", [unlockTime], owner);
    return { lock, owner, unlockTime };
  }

  it("Should set the correct unlock time and owner", async function () {
    const { lock, owner, unlockTime } =
      await networkHelpers.loadFixture(deployLockFixture);

    expect(await lock.unlockTime()).to.equal(unlockTime);
    expect(await lock.owner()).to.equal(owner.address);
  });
});
