pragma solidity 0.8.16;

interface ISanctionsOracle {
  function addToSanctionsList(address[] memory newSanctions) external;

  function removeFromSanctionsList(address[] memory removeSanctions) external;

  function name() external pure returns (string memory);

  function isSanctioned(address addr) external view returns (bool);

  function owner() external view returns (address);
}
