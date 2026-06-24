# contract-starter-ethereum

A dual-toolchain Ethereum smart contract starter (Hardhat + Foundry), with optional [Base B-20](https://github.com/base/base-std) fork integration tests in `test_forge/`.

## Stack

| Layer           | Path            | Tooling                          |
| --------------- | --------------- | -------------------------------- |
| Contracts       | `contracts/`    | Hardhat, Foundry (`forge build`) |
| Hardhat tests   | `test_hardhat/` | Mocha, `yarn test:hardhat`       |
| Forge tests     | `test_forge/`   | Foundry, `yarn test:forge`       |
| Base interfaces | `lib/base-std/` | `base-std` git submodule / lib   |

Solidity **0.8.34**, IR pipeline enabled (`via_ir`), EVM **Osaka**.

## Quick start

```bash
yarn install
cp .env.example .env   # fill RPC URLs and keys

# Restore Cursor / agent skills pinned in skills-lock.json
npx skills experimental_install

yarn build
yarn test
```

## Agent skills

This repo ships [agent skills](https://skills.sh/) — modular instruction packs for AI coding agents (Cursor, Claude Code, etc.). Locked versions live in `skills-lock.json`; installed files land under `.agents/skills/`.

### Install (recommended)

From the repo root, restore every skill pinned in the lockfile:

```bash
npx skills experimental_install
```

Run this after `git clone` or whenever `.agents/skills/` is missing. No global install required — `npx` fetches the Skills CLI on demand.

### Bundled skills

| Skill                     | Source                                                                                  | Use for                                            |
| ------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `defi-protocol-templates` | [wshobson/agents](https://github.com/wshobson/agents)                                   | Staking, AMM, governance, lending templates        |
| `nft-standards`           | [wshobson/agents](https://github.com/wshobson/agents)                                   | ERC-721 / ERC-1155, metadata, minting              |
| `solidity-security`       | [wshobson/agents](https://github.com/wshobson/agents)                                   | Secure Solidity patterns, vulnerability prevention |
| `web3-testing`            | [wshobson/agents](https://github.com/wshobson/agents)                                   | Hardhat / Foundry test suites, fork testing        |
| `slowmist-agent-security` | [slowmist/slowmist-agent-security](https://github.com/slowmist/slowmist-agent-security) | Security review for skills, MCP, repos, contracts  |

## Environment

Fork tests against Base Sepolia read from `.env`:

| Variable                   | Purpose                                       |
| -------------------------- | --------------------------------------------- |
| `BASE_SEPOLIA_RPC_URL`     | RPC for `vm.createSelectFork("base_sepolia")` |
| `BASE_SEPOLIA_PRIVATE_KEY` | Deployer key used in fork integration tests   |

Other networks (`SEPOLIA_*`, `BASE_*`, etc.) are wired in `foundry.toml` for general use.

## Testing

### Local (no RPC)

```bash
yarn test:forge      # all Forge tests except live-precompile forks
yarn test:hardhat
```

Stock `forge` runs fork tests but **skips** them when Base precompiles are unavailable on the fork.

### Base B-20 fork tests (Base Sepolia)

B-20, PolicyRegistry, and ActivationRegistry are **chain-native precompiles**. Stock Foundry cannot dispatch them on a fork; use [base-forge](https://github.com/base/base-anvil):

```bash
# Install base-forge (coexists with stock Foundry)
curl -L https://raw.githubusercontent.com/base/base-anvil/HEAD/foundryup/install | bash
base-foundryup

# Run B-20 fork suites
base-forge test --match-contract B20FactoryForkTest -vvv
base-forge test --match-contract B20StablecoinOutboundBlacklistTest -vvv
```

Or via yarn:

```bash
yarn test:base-forge   # B20FactoryForkTest only
```

Required on-chain features must be activated on the forked network. Tests call `vm.skip` when a feature or precompile is unavailable — a skip is not a pass. See [base-std docs](https://github.com/base/base-std/tree/main/docs) for B-20, PolicyRegistry, and ActivationRegistry specs.

## Project layout

```
contracts/           # application contracts (Lock, ERC7913SignatureVerifier, …)
test_hardhat/        # Hardhat / Mocha tests
test_forge/          # Foundry tests (including Base fork suites)
.agents/skills/      # agent skills (restore via npx skills experimental_install)
skills-lock.json     # pinned skill versions for reproducible installs
lib/base-std/        # Base precompile interfaces & helpers
lib/forge-std/       # Foundry test utilities
foundry.toml         # Forge config & RPC aliases
hardhat.config.ts    # Hardhat config
```

## References

- [base-std](https://github.com/base/base-std) — B-20 interfaces, precompile specs, fork testing guide
- [base-anvil / base-forge](https://github.com/base/base-anvil) — patched Foundry for Base precompiles

## License

MIT
