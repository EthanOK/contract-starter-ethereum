import { expect } from "chai";
import { ethers, ZeroAddress } from "ethers";
import { network } from "hardhat";

const { ethers: hhEthers, networkHelpers } = await network.connect();

const ERC1271_MAGIC_VALUE = "0x1626ba7e";
const ERC1271_INVALID = "0xffffffff";

const message = "Hello, world!";

const EIP712_SAFE_MESSAGE_TYPE = {
  SafeMessage: [{ name: "message", type: "string" }],
};

function addressToSignerBytes(addr: string): string {
  return ethers.solidityPacked(["address"], [addr]);
}

async function signMessage(
  signer: ethers.Signer,
  message: string | Uint8Array,
): Promise<string> {
  const sig = await signer.signMessage(message);
  return sig;
}

async function signTypedData(
  signer: ethers.Signer,
  domain: ethers.TypedDataDomain,
  types: Record<string, Array<ethers.TypedDataField>>,
  value: Record<string, any>,
): Promise<string> {
  const sig = await signer.signTypedData(domain, types, value);

  return sig;
}

async function buildMultisigSignatureWithMessage(
  message: string | Uint8Array,
  signers: ethers.Signer[],
): Promise<{ digest: string; signature: string }> {
  const signerBytes = signers.map((s) =>
    addressToSignerBytes((s as ethers.Wallet).address),
  );
  const signatures = await Promise.all(
    signers.map((s) => signMessage(s, message)),
  );

  const withHash = signerBytes.map((b, i) => ({
    id: ethers.keccak256(b),
    signer: b,
    sig: signatures[i],
  }));
  withHash.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));

  const orderedSigners = withHash.map((x) => x.signer);
  const orderedSigs = withHash.map((x) => x.sig);

  const digest = ethers.hashMessage(message);

  const signature = ethers.AbiCoder.defaultAbiCoder().encode(
    ["bytes[]", "bytes[]"],
    [orderedSigners, orderedSigs],
  );

  return { digest, signature };
}

async function buildMultisigSignatureWithEIP712TypeData(
  domain: ethers.TypedDataDomain,
  types: Record<string, Array<ethers.TypedDataField>>,
  value: Record<string, any>,
  signers: ethers.Signer[],
): Promise<{ digest: string; signature: string }> {
  const signerBytes = signers.map((s) =>
    addressToSignerBytes((s as ethers.Wallet).address),
  );

  const signatures = await Promise.all(
    signers.map((s) => signTypedData(s, domain, types, value)),
  );

  const withHash = signerBytes.map((b, i) => ({
    id: ethers.keccak256(b),
    signer: b,
    sig: signatures[i],
  }));
  withHash.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));

  const orderedSigners = withHash.map((x) => x.signer);
  const orderedSigs = withHash.map((x) => x.sig);

  const digest = ethers.TypedDataEncoder.hash(domain, types, value);

  const signature = ethers.AbiCoder.defaultAbiCoder().encode(
    ["bytes[]", "bytes[]"],
    [orderedSigners, orderedSigs],
  );

  return { digest, signature };
}

describe("ERC7913SignatureVerifier", function () {
  async function deployFixture() {
    const [owner, signer1, signer2, other] = await hhEthers.getSigners();
    const chainId = (await hhEthers.provider.getNetwork()).chainId;
    const signers = [
      addressToSignerBytes(signer1.address),
      addressToSignerBytes(signer2.address),
    ];
    const threshold = 2;

    const verifier = await hhEthers.deployContract(
      "ERC7913SignatureVerifier",
      [signers, threshold],
      owner,
    );
    return { verifier, owner, signer1, signer2, other, chainId };
  }

  it("should return true for valid message signature", async function () {
    const { verifier, owner, signer1, signer2, other } =
      await networkHelpers.loadFixture(deployFixture);

    const isSigner = await verifier.isSigner(
      addressToSignerBytes(signer1.address),
    );
    expect(isSigner).to.be.true;

    const signerCount = await verifier.getSignerCount();
    expect(signerCount).to.be.equal(2);
    const signers = await verifier.getSigners(0, signerCount);
    expect(signers.length).to.be.equal(2);
    const { digest, signature } = await buildMultisigSignatureWithMessage(
      message,
      [signer1 as any, signer2 as any],
    );

    const result = await verifier.isValidSignature(digest, signature);

    expect(result).to.be.equal(ERC1271_MAGIC_VALUE);
  });

  it("should return true for valid EIP712 message signature", async function () {
    const { verifier, owner, signer1, signer2, other, chainId } =
      await networkHelpers.loadFixture(deployFixture);

    const domain = {
      verifyingContract: await verifier.getAddress(),
      chainId: chainId,
    };
    const types = EIP712_SAFE_MESSAGE_TYPE;
    const value = { message: message };

    const { digest, signature } =
      await buildMultisigSignatureWithEIP712TypeData(domain, types, value, [
        signer1 as any,
        signer2 as any,
      ]);
    const result = await verifier.isValidSignature(digest, signature);

    expect(result).to.be.equal(ERC1271_MAGIC_VALUE);
  });

  it("should return false for invalid message signature", async function () {
    const { verifier, owner, signer1, signer2, other } =
      await networkHelpers.loadFixture(deployFixture);

    const isSigner = await verifier.isSigner(
      addressToSignerBytes(signer1.address),
    );
    expect(isSigner).to.be.true;

    const signerCount = await verifier.getSignerCount();
    expect(signerCount).to.be.equal(2);
    const signers = await verifier.getSigners(0, signerCount);
    expect(signers.length).to.be.equal(2);
    const { digest, signature } = await buildMultisigSignatureWithMessage(
      message,
      [signer1 as any, other as any],
    );

    const result = await verifier.isValidSignature(digest, signature);

    expect(result).to.be.equal(ERC1271_INVALID);
  });

  it("should return false for invalid EIP712 message signature", async function () {
    const { verifier, owner, signer1, signer2, other, chainId } =
      await networkHelpers.loadFixture(deployFixture);

    const domain = {
      verifyingContract: await verifier.getAddress(),
      chainId: chainId,
    };
    const types = EIP712_SAFE_MESSAGE_TYPE;
    const value = { message: message };

    const { digest, signature } =
      await buildMultisigSignatureWithEIP712TypeData(domain, types, value, [
        signer1 as any,
        other as any,
      ]);
    const result = await verifier.isValidSignature(digest, signature);

    expect(result).to.be.equal(ERC1271_INVALID);
  });
});
