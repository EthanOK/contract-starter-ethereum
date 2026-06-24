// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {Test, console2} from "forge-std/Test.sol";

import {IB20} from "base-std/interfaces/IB20.sol";
import {IB20Asset} from "base-std/interfaces/IB20Asset.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {IB20Stablecoin} from "base-std/interfaces/IB20Stablecoin.sol";
import {IActivationRegistry} from "base-std/interfaces/IActivationRegistry.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";

/// @notice Integration tests for the B20Factory precompile on a forked Base Sepolia.
/// @dev    Fork happens in setUp via `vm.createSelectFork("base_sepolia")` (RPC alias in foundry.toml).
///         Stock `forge` cannot dispatch Base precompiles on a fork; use `base-forge test --base`.
contract B20FactoryForkTest is Test {
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

    /// @dev keccak256("base.b20_asset")
    bytes32 internal constant FEATURE_B20_ASSET = 0xcdcc772fe4cbdb1029f822861176d09e646db96723d4c1e82ddfdeb8163ef54c;
    /// @dev keccak256("base.b20_stablecoin")
    bytes32 internal constant FEATURE_B20_STABLECOIN =
        0xecfa0def2c10020caaf65e6155aa69c84b24892aaef76eeac52e0e2b3a0b8601;

    IB20Factory internal factory = StdPrecompiles.B20_FACTORY;
    IActivationRegistry internal activationRegistry = StdPrecompiles.ACTIVATION_REGISTRY;

    address internal deployer;

    function setUp() public {
        vm.createSelectFork("base_sepolia");
        assertEq(block.chainid, BASE_SEPOLIA_CHAIN_ID, "unexpected fork chain id");

        if (!_hasLivePrecompiles()) {
            vm.skip(true, "Base precompiles unavailable on this fork; install base-forge and run with --base");
        }

        deployer = vm.addr(vm.envUint("BASE_SEPOLIA_PRIVATE_KEY"));
        vm.deal(deployer, 10 ether);
        vm.label(deployer, "deployer");

        console2.log("fork chainId:", block.chainid);
        console2.log("activation admin:", activationRegistry.admin());
        console2.log("B20_ASSET activated:", activationRegistry.isActivated(FEATURE_B20_ASSET));
        console2.log("B20_STABLECOIN activated:", activationRegistry.isActivated(FEATURE_B20_STABLECOIN));
    }

    function test_fork_getB20Address_isDeterministic() public view {
        bytes32 salt = keccak256("fork-determinism");
        address predicted = factory.getB20Address(IB20Factory.B20Variant.STABLECOIN, deployer, salt);

        bytes9 expectedTail = bytes9(keccak256(abi.encode(deployer, salt)));
        uint160 expectedAddr = (uint160(0xB2) << 152) |
            (uint160(uint8(IB20Factory.B20Variant.STABLECOIN)) << 72) |
            uint160(uint72(expectedTail));

        assertEq(predicted, address(expectedAddr), "getB20Address must match abi.encode derivation");
        assertTrue(factory.isB20(predicted), "predicted address must match B-20 prefix");
        assertFalse(factory.isB20Initialized(predicted), "predicted address must not be initialized yet");
    }

    function test_fork_createStablecoin() public {
        _requireFeature(FEATURE_B20_STABLECOIN);

        bytes32 salt = keccak256(abi.encodePacked("stablecoin", block.timestamp, deployer));
        IB20Factory.B20StablecoinCreateParams memory params = IB20Factory.B20StablecoinCreateParams({
            version: B20FactoryLib.B20_STABLECOIN_CREATE_PARAMS_VERSION,
            name: "Fork USD",
            symbol: "FUSD",
            initialAdmin: deployer,
            currency: "USD"
        });

        address predicted = factory.getB20Address(IB20Factory.B20Variant.STABLECOIN, deployer, salt);

        vm.prank(deployer);
        address token = factory.createB20(IB20Factory.B20Variant.STABLECOIN, salt, abi.encode(params), new bytes[](0));

        assertEq(token, predicted, "createB20 address must match prediction");
        assertGt(token.code.length, 0, "live B-20 must have bytecode stub after creation");
        assertTrue(factory.isB20Initialized(token), "token must be marked initialized");
        assertEq(IB20Stablecoin(token).currency(), "USD", "currency must round-trip");
        assertEq(IB20(token).name(), "Fork USD", "name must round-trip");
        assertEq(IB20(token).symbol(), "FUSD", "symbol must round-trip");
    }

    function test_fork_createAsset() public {
        _requireFeature(FEATURE_B20_ASSET);

        bytes32 salt = keccak256(abi.encodePacked("asset", block.timestamp, deployer));
        IB20Factory.B20AssetCreateParams memory params = IB20Factory.B20AssetCreateParams({
            version: B20FactoryLib.B20_ASSET_CREATE_PARAMS_VERSION,
            name: "Fork Asset",
            symbol: "FAST",
            initialAdmin: deployer,
            decimals: 18
        });

        address predicted = factory.getB20Address(IB20Factory.B20Variant.ASSET, deployer, salt);

        vm.prank(deployer);
        address token = factory.createB20(IB20Factory.B20Variant.ASSET, salt, abi.encode(params), new bytes[](0));

        assertEq(token, predicted, "createB20 address must match prediction");
        assertGt(token.code.length, 0, "live B-20 must have bytecode stub after creation");
        assertTrue(factory.isB20Initialized(token), "token must be marked initialized");
        assertEq(IB20Asset(token).decimals(), 18, "decimals must round-trip");
        assertEq(IB20(token).name(), "Fork Asset", "name must round-trip");
        assertEq(IB20(token).symbol(), "FAST", "symbol must round-trip");
    }

    function _hasLivePrecompiles() private view returns (bool) {
        if (vm.envOr("LIVE_PRECOMPILES", false)) return true;

        (bool ok, bytes memory ret) = address(activationRegistry).staticcall(
            abi.encodeCall(IActivationRegistry.admin, ())
        );
        return ok && ret.length >= 32;
    }

    function _requireFeature(bytes32 feature) private {
        if (!activationRegistry.isActivated(feature)) {
            vm.skip(true, "B-20 feature not activated on this Base Sepolia fork yet");
        }
    }
}

// base-forge test --match-contract B20FactoryForkTest -vvv
