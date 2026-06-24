// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import {Test, console2} from "forge-std/Test.sol";

import {IB20} from "base-std/interfaces/IB20.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {IB20Stablecoin} from "base-std/interfaces/IB20Stablecoin.sol";
import {IActivationRegistry} from "base-std/interfaces/IActivationRegistry.sol";
import {IPolicyRegistry} from "base-std/interfaces/IPolicyRegistry.sol";
import {B20Constants} from "base-std/lib/B20Constants.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";

/// @notice Fork integration: stablecoin with an outbound (sender-side) transfer blocklist.
/// @dev    Outbound blacklist = `TRANSFER_SENDER_POLICY` + PolicyRegistry `BLOCKLIST`.
///         Run: base-forge test --match-contract B20StablecoinOutboundBlacklistTest -vvv
contract B20StablecoinOutboundBlacklistTest is Test {
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 internal constant ONE_TOKEN = 1_000_000; // stablecoin fixed 6 decimals

    /// @dev keccak256("base.b20_stablecoin")
    bytes32 internal constant FEATURE_B20_STABLECOIN =
        0xecfa0def2c10020caaf65e6155aa69c84b24892aaef76eeac52e0e2b3a0b8601;
    /// @dev keccak256("base.policy_registry")
    bytes32 internal constant FEATURE_POLICY_REGISTRY =
        0xb582ebae03f16fee49a6763f78df482fb11ae73f103ed0d330bbe556aa90a43f;

    IB20Factory internal factory = StdPrecompiles.B20_FACTORY;
    IActivationRegistry internal activationRegistry = StdPrecompiles.ACTIVATION_REGISTRY;
    IPolicyRegistry internal policyRegistry = StdPrecompiles.POLICY_REGISTRY;

    address internal deployer;
    address internal blockedSender = makeAddr("blockedSender");
    address internal allowedSender = makeAddr("allowedSender");
    address internal recipient = makeAddr("recipient");

    function setUp() public {
        vm.createSelectFork("base_sepolia");
        assertEq(block.chainid, BASE_SEPOLIA_CHAIN_ID, "unexpected fork chain id");

        if (!_hasLivePrecompiles()) {
            vm.skip(true, "Base precompiles unavailable on this fork; install base-forge and run with --base");
        }

        deployer = vm.addr(vm.envUint("BASE_SEPOLIA_PRIVATE_KEY"));
        vm.deal(deployer, 10 ether);
        vm.label(deployer, "deployer");
        vm.label(blockedSender, "blockedSender");
        vm.label(allowedSender, "allowedSender");
        vm.label(recipient, "recipient");
    }

    function test_fork_stablecoin_outboundSenderBlocklist() public {
        _requireFeature(FEATURE_B20_STABLECOIN);
        _requireFeature(FEATURE_POLICY_REGISTRY);

        uint64 outboundBlocklist = _createOutboundBlocklist(blockedSender);

        bytes32 salt = keccak256(abi.encodePacked("outbound-blocklist", block.timestamp, deployer));
        IB20 token = IB20(_deployStablecoinWithSenderPolicy(salt, outboundBlocklist));

        assertEq(
            token.policyId(B20Constants.TRANSFER_SENDER_POLICY),
            outboundBlocklist,
            "TRANSFER_SENDER_POLICY must reference outbound blocklist"
        );
        assertEq(token.balanceOf(blockedSender), ONE_TOKEN, "blocked sender must hold tokens");
        assertEq(token.balanceOf(allowedSender), ONE_TOKEN, "allowed sender must hold tokens");

        vm.prank(blockedSender);
        vm.expectRevert(
            abi.encodeWithSelector(IB20.PolicyForbids.selector, B20Constants.TRANSFER_SENDER_POLICY, outboundBlocklist)
        );
        token.transfer(recipient, 100_000);

        vm.prank(allowedSender);
        token.transfer(recipient, 100_000);

        assertEq(token.balanceOf(recipient), 100_000, "only allowed sender may transfer out");
        assertEq(token.balanceOf(blockedSender), ONE_TOKEN, "blocked sender balance unchanged");
        assertEq(token.balanceOf(allowedSender), ONE_TOKEN - 100_000, "allowed sender debited");

        console2.log("outbound blocklist policyId:", outboundBlocklist);
        console2.log("stablecoin:", address(token));
    }

    /// @notice Creates a BLOCKLIST policy and blocks `account` from sending transfers.
    function _createOutboundBlocklist(address account) internal returns (uint64 policyId) {
        vm.prank(deployer);
        policyId = policyRegistry.createPolicy(deployer, IPolicyRegistry.PolicyType.BLOCKLIST);
        assertTrue(policyRegistry.policyExists(policyId), "policy must exist after creation");

        address[] memory accounts = new address[](1);
        accounts[0] = account;

        vm.prank(deployer);
        policyRegistry.updateBlocklist(policyId, true, accounts);

        assertFalse(policyRegistry.isAuthorized(policyId, account), "blocked account must fail isAuthorized");
        assertTrue(policyRegistry.isAuthorized(policyId, allowedSender), "non-blocked account must pass");
    }

    /// @notice Deploys a stablecoin whose `TRANSFER_SENDER_POLICY` points at `senderPolicyId`.
    function _deployStablecoinWithSenderPolicy(bytes32 salt, uint64 senderPolicyId) internal returns (address token) {
        IB20Factory.B20StablecoinCreateParams memory params = IB20Factory.B20StablecoinCreateParams({
            version: B20FactoryLib.B20_STABLECOIN_CREATE_PARAMS_VERSION,
            name: "Blocked Out USD",
            symbol: "BOUSD",
            initialAdmin: deployer,
            currency: "USD"
        });

        bytes[] memory initCalls = new bytes[](4);
        initCalls[0] = B20FactoryLib.encodeUpdatePolicy(B20Constants.TRANSFER_SENDER_POLICY, senderPolicyId);
        initCalls[1] = B20FactoryLib.encodeGrantRole(B20Constants.MINT_ROLE, deployer);
        initCalls[2] = abi.encodeCall(IB20.mint, (blockedSender, ONE_TOKEN));
        initCalls[3] = abi.encodeCall(IB20.mint, (allowedSender, ONE_TOKEN));

        vm.prank(deployer);
        token = factory.createB20(IB20Factory.B20Variant.STABLECOIN, salt, abi.encode(params), initCalls);

        assertTrue(factory.isB20Initialized(token), "token must be initialized");
        assertEq(IB20Stablecoin(token).currency(), "USD", "currency must round-trip");
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
            vm.skip(true, "required Base feature not activated on this fork yet");
        }
    }
}
