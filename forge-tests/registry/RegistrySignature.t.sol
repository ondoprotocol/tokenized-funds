// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";
import "forge-std/console2.sol";
import "contracts/external/openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SigUtils {
  bytes32 internal DOMAIN_SEPARATOR;
  bytes32 internal APPROVAL_TYPEHASH;

  constructor(bytes32 _DOMAIN_SEPARATOR, bytes32 _APPROVAL_TYPEHASH) {
    DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    APPROVAL_TYPEHASH = _APPROVAL_TYPEHASH;
  }

  struct KYCApproval {
    uint256 kycRequirementGroup;
    address user;
    uint256 deadline;
  }

  // Computes the hash of a KYCApproval
  function getStructHash(
    KYCApproval memory _approval
  ) internal view returns (bytes32) {
    return
      keccak256(
        abi.encode(
          APPROVAL_TYPEHASH,
          _approval.kycRequirementGroup,
          _approval.user,
          _approval.deadline
        )
      );
  }

  function getTypedDataHash(
    KYCApproval memory _approval
  ) public view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_approval))
      );
  }
}

contract TestKYCRegistry is BasicDeployment {
  address verifyingContract = address(registry);
  SigUtils internal sigUtils;
  uint256 internal signerPrivateKey;
  address internal signer;
  bytes32 public constant KYC_GROUP_1_ROLE = keccak256("KYC_GROUP_1_ROLE");

  address user1 = address(0x5);
  address user2 = address(0x6);
  uint256 deadline = 500;

  uint8 v;
  bytes32 r;
  bytes32 s;

  function setUp() public {
    deployKYCRegistry();
    sigUtils = new SigUtils(
      registry.DOMAIN_SEPARATOR(),
      registry._APPROVAL_TYPEHASH()
    );
    signerPrivateKey = 0xB0B;
    signer = vm.addr(signerPrivateKey);
    vm.startPrank(registryAdmin);
    registry.assignRoletoKYCGroup(1, KYC_GROUP_1_ROLE);
    // Signer can sign transactions that modify kyc requirement group 1.
    registry.grantRole(KYC_GROUP_1_ROLE, signer);
    vm.stopPrank();
    vm.warp(deadline - 1);

    // Create signature under test
    SigUtils.KYCApproval memory approval = SigUtils.KYCApproval({
      kycRequirementGroup: 1,
      user: user1,
      deadline: deadline
    });
    // EIP 712
    bytes32 digest = sigUtils.getTypedDataHash(approval);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(signerPrivateKey, digest);
    v = _v;
    r = _r;
    s = _s;
  }

  function test_unit_signature_add_happy_case() public {
    vm.expectEmit(true, true, true, true);
    emit KYCAddressAddViaSignature(address(this), user1, signer, 1, deadline);
    registry.addKYCAddressViaSignature(1, user1, deadline, v, r, s);
    assertEq(registry.getKYCStatus(1, user1), true);
  }

  function test_unit_signature_add_fail_because_noop() public {
    registry.addKYCAddressViaSignature(1, user1, deadline, v, r, s);
    assertEq(registry.getKYCStatus(1, user1), true);
    // Revert rather than perform no-op operation.
    vm.expectRevert("KYCRegistry: user already verified");
    registry.addKYCAddressViaSignature(1, user1, deadline, v, r, s);
    assertEq(registry.getKYCStatus(1, user1), true);
  }

  function test_unit_signature_add_fail_expiry() public {
    // Change Block.timestamp to be > deadline
    vm.warp(501);
    vm.expectRevert("KYCRegistry: signature expired");
    registry.addKYCAddressViaSignature(1, user1, deadline, v, r, s);
    assertEq(registry.getKYCStatus(1, user1), false);
  }

  function test_unit_signature_add_fail_bad_v() public {
    vm.expectRevert("KYCRegistry: invalid v value in signature");
    registry.addKYCAddressViaSignature(1, user1, deadline, 29, r, s);
    vm.expectRevert("KYCRegistry: invalid v value in signature");
    registry.addKYCAddressViaSignature(1, user1, deadline, 26, r, s);
    assertEq(registry.getKYCStatus(1, user1), false);
  }

  function test_unit_signature_add_group_mismatch() public {
    SigUtils.KYCApproval memory approval = SigUtils.KYCApproval({
      kycRequirementGroup: 2, // Group 2 instead of 1
      user: user1,
      deadline: deadline
    });
    bytes32 digest = sigUtils.getTypedDataHash(approval);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(signerPrivateKey, digest);
    // Will revert based on "access control"
    // because the groups mismatch in the computed hashes
    // causing ecrecover to resolve to an incorrect address (0x62...);
    vm.expectRevert(
      _formatACRevert(
        address(0xA04476a7Ed0401D81d0192c22EE55B7b59c1EE6a),
        KYC_GROUP_1_ROLE
      )
    );
    registry.addKYCAddressViaSignature(1, user1, deadline, _v, _r, _s);
  }

  function test_unit_signature_add_fail_access_control() public {
    SigUtils.KYCApproval memory approval = SigUtils.KYCApproval({
      kycRequirementGroup: 2, // Group 2 instead of 1
      user: user1,
      deadline: deadline
    });
    bytes32 digest = sigUtils.getTypedDataHash(approval);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(signerPrivateKey, digest);

    // Signature is correct, but signer doesn't have access to add to kyc
    // requirement group 2.
    vm.expectRevert(_formatACRevert(signer, KYC_GROUP_2_ROLE));
    registry.addKYCAddressViaSignature(2, user1, deadline, _v, _r, _s);
  }

  function test_unit_signature_add_fail_bad_user() public {
    // Will revert based on "access control"
    // because the users mismatch in the computed hashes
    // causing ecrecover to resolve to an incorrect address
    vm.expectRevert(
      _formatACRevert(
        address(0xC6ee2603b208983BED1764f9F46DD902384dB9F1),
        KYC_GROUP_1_ROLE
      )
    );
    // User 2 instead of user 1
    registry.addKYCAddressViaSignature(1, user2, deadline, v, r, s);
  }

  function test_unit_signature_add_fail_bad_deadline() public {
    // Will revert based on "access control"
    // because the deadlines mismatch in the computed hashes
    // causing ecrecover to resolve to an incorrect address
    vm.expectRevert(
      _formatACRevert(
        address(0x6576698Af915dfCf3982f18C2b328C0d06681d61),
        KYC_GROUP_1_ROLE
      )
    );
    // Deadline is different than what is hashed and signed.
    registry.addKYCAddressViaSignature(1, user1, deadline + 100, v, r, s);
  }
}
