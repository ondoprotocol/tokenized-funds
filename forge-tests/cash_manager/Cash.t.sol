// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/cash_manager/Minting.t.sol";
import "forge-tests/cash_manager/Redemption.t.sol";

contract TestCashManager_Cash is TestCashMinting, TestCashRedemption {
  function setUp() public {
    createDeploymentCash();

    // Grant Setter
    vm.startPrank(managerAdmin);
    cashManager.grantRole(cashManager.SETTER_ADMIN(), address(this));
    cashManager.grantRole(cashManager.SETTER_ADMIN(), managerAdmin);
    vm.stopPrank();

    // Seed address with 1000000 USDC
    vm.prank(usdcWhale);
    usdc.transfer(address(this), INIT_BALANCE_USDC);

    // Add KYC addresses
    address[] memory addressesToKYC = new address[](5);
    addressesToKYC[0] = guardian;
    addressesToKYC[1] = address(cashManager);
    addressesToKYC[2] = alice;
    addressesToKYC[3] = bob;
    addressesToKYC[4] = charlie;
    registry.addKYCAddresses(kycRequirementGroup, addressesToKYC);
    registry.addKYCAddresses(kycRequirementGroup, users); // Add 100 redemption users to KYC list
  }
}
