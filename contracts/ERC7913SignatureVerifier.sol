// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {MultiSignerERC7913} from "@openzeppelin/contracts/utils/cryptography/signers/MultiSignerERC7913.sol";

/**
 * @title ERC7913SignatureVerifier
 * @notice Minimal contract to verify ERC-7913 multisig signatures
 */
contract ERC7913SignatureVerifier is IERC1271, MultiSignerERC7913 {
    constructor(bytes[] memory signers, uint64 threshold) MultiSignerERC7913(signers, threshold) {}

    function isValidSignature(bytes32 hash, bytes calldata signature) external view override returns (bytes4) {
        return _rawSignatureValidation(hash, signature) ? IERC1271.isValidSignature.selector : bytes4(0xffffffff);
    }
}
