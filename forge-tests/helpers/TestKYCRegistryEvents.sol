pragma solidity 0.8.16;

contract TestKYCRegistryEvents {
  event RoleAssignedToKYCGroup(
    uint256 indexed kycRequirementGroup,
    bytes32 indexed role
  );

  event KYCAddressesAdded(
    address indexed sender,
    uint256 indexed kycRequirementGroup,
    address[] addresses
  );

  event KYCAddressesRemoved(
    address indexed sender,
    uint256 indexed kycRequirementGroup,
    address[] addresses
  );

  event KYCRegistrySet(address oldRegistry, address newRegistry);

  event KYCRequirementGroupSet(
    uint256 oldRequirementGroup,
    uint256 newRequirementGroup
  );

  event KYCAddressAddViaSignature(
    address indexed sender,
    address indexed user,
    address indexed signer,
    uint256 kycRequirementGroup,
    uint256 deadline
  );
}
