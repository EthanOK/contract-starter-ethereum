// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script, console2} from "forge-std/Script.sol";

import {IB20} from "base-std/interfaces/IB20.sol";
import {IB20Asset} from "base-std/interfaces/IB20Asset.sol";
import {IB20Stablecoin} from "base-std/interfaces/IB20Stablecoin.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {IPolicyRegistry} from "base-std/interfaces/IPolicyRegistry.sol";
import {B20Constants} from "base-std/lib/B20Constants.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";

/// @notice Deploys B-20 tokens via the Base B20Factory precompile.
/// @dev    B-20 is a Base-native precompile; deploy only on Base / Base Sepolia
///         (stock anvil/forge can't dispatch it). Use base-forge for script simulation.
contract B20Script is Script {
    IB20Factory internal factory = StdPrecompiles.B20_FACTORY;
    IPolicyRegistry internal policies = StdPrecompiles.POLICY_REGISTRY;

    /// @dev 100M tokens; stablecoin uses 6 decimals, asset uses 18.
    uint256 internal constant INITIAL_STABLECOIN_SUPPLY = 100_000_000 * 1e6;
    uint256 internal constant INITIAL_ASSET_SUPPLY = 100_000_000 * 1e18;

    /// @notice Deploys a USD stablecoin. Run by default.
    function run() public {
        deployStablecoin();
    }

    /// @notice Creates a STABLECOIN with outbound sender blocklist + 100M initial mint.
    /// @dev    Empty blocklist; add senders later via `policies.updateBlocklist(policyId, true, accounts)`.
    function deployStablecoin() public returns (address token, uint64 blocklistId) {
        uint256 pk = vm.envUint("BASE_SEPOLIA_PRIVATE_KEY");
        address deployer = vm.addr(pk);
        console2.log("deployer:", deployer);
        bytes32 salt = keccak256(abi.encodePacked("stablecoin", block.chainid, deployer));

        IB20Factory.B20StablecoinCreateParams memory params = IB20Factory.B20StablecoinCreateParams({
            version: B20FactoryLib.B20_STABLECOIN_CREATE_PARAMS_VERSION,
            name: "Bric USD",
            symbol: "BUSD",
            initialAdmin: deployer,
            currency: "USD"
        });

        console2.log("predicted stablecoin:", factory.getB20Address(IB20Factory.B20Variant.STABLECOIN, deployer, salt));

        vm.startBroadcast(pk);

        blocklistId = policies.createPolicy(deployer, IPolicyRegistry.PolicyType.BLOCKLIST);

        bytes[] memory initCalls = new bytes[](2);
        initCalls[0] = B20FactoryLib.encodeUpdatePolicy(B20Constants.TRANSFER_SENDER_POLICY, blocklistId);
        initCalls[1] = abi.encodeCall(IB20.mint, (deployer, INITIAL_STABLECOIN_SUPPLY));

        token = factory.createB20(IB20Factory.B20Variant.STABLECOIN, salt, abi.encode(params), initCalls);

        vm.stopBroadcast();

        console2.log("deployed stablecoin:", token);
        console2.log("outbound blocklist policyId:", blocklistId);
        console2.log("currency:", IB20Stablecoin(token).currency());
        console2.log("initial supply:", IB20(token).totalSupply());
    }

    /// @notice Creates an ASSET with outbound sender blocklist + 100M initial mint.
    function deployAsset() public returns (address token, uint64 blocklistId) {
        uint256 pk = vm.envUint("BASE_SEPOLIA_PRIVATE_KEY");
        address deployer = vm.addr(pk);
        console2.log("deployer:", deployer);
        bytes32 salt = keccak256(abi.encodePacked("asset", block.chainid, deployer));

        IB20Factory.B20AssetCreateParams memory params = IB20Factory.B20AssetCreateParams({
            version: B20FactoryLib.B20_ASSET_CREATE_PARAMS_VERSION,
            name: "Bric Asset",
            symbol: "BAST",
            initialAdmin: deployer,
            decimals: 18
        });

        vm.startBroadcast(pk);

        blocklistId = policies.createPolicy(deployer, IPolicyRegistry.PolicyType.BLOCKLIST);

        bytes[] memory initCalls = new bytes[](2);
        initCalls[0] = B20FactoryLib.encodeUpdatePolicy(B20Constants.TRANSFER_SENDER_POLICY, blocklistId);
        initCalls[1] = abi.encodeCall(IB20.mint, (deployer, INITIAL_ASSET_SUPPLY));

        token = factory.createB20(IB20Factory.B20Variant.ASSET, salt, abi.encode(params), initCalls);

        vm.stopBroadcast();

        console2.log("deployed asset:", token);
        console2.log("outbound blocklist policyId:", blocklistId);
        console2.log("decimals:", IB20Asset(token).decimals());
        console2.log("initial supply:", IB20(token).totalSupply());
    }
}

// Stablecoin (default):
//   base-forge script script/B20.s.sol --rpc-url base_sepolia --broadcast
// Asset:
//   base-forge script script/B20.s.sol --sig "deployAsset()" --rpc-url base_sepolia --broadcast
