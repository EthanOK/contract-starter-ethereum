// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const JAN_1ST_2030 = 1893456000;
const ONE_GWEI: bigint = 1_000_000_000n;

const LockModule = buildModule("LockModule", (m) => {
  const unlockTime = m.getParameter("unlockTime", JAN_1ST_2030);
  const lockedAmount = m.getParameter("lockedAmount", ONE_GWEI);

  const lock = m.contract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  m.call(lock, "rescue");

  return { lock };
});

export default LockModule;
// deploy
// yarn hardhat ignition deploy ignition/modules/Lock.ts --network sepolia

// verify
// yarn hardhat verify --network sepolia 0x8DA46934989084251B51C89549B29adBc764109d 1893456000
