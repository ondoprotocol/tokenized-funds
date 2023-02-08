// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";

contract TestCashToken is BasicDeployment {
  function setUp() public {
    deployCashToken();
  }

  function test_unit_cashToken_pause() public {
    vm.prank(guardian);
    cashProxied.pause();
    assertEq(cashProxied.paused(), true);
  }

  function test_unit_cashToken_mint_fail_paused() public {
    // Pause Contract
    vm.startPrank(guardian);
    cashProxied.pause();

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashProxied.mint(address(this), 1);
  }

  function test_unit_cashToken_transfer_fail_paused() public {
    // Mint and Grant TRANSFER_ROLE to current contract
    vm.startPrank(guardian);
    cashProxied.mint(address(this), 1); // Mint to current contract
    cashProxied.grantRole(cashProxied.TRANSFER_ROLE(), address(this)); // Grant transfer role to current contract

    // Pause
    cashProxied.pause();
    vm.stopPrank();

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashProxied.transfer(alice, 1);
  }

  function test_unit_cashToken_transfer_withTransferRole() public {
    // Mint and grant TRANSFER_ROLE to current contract
    vm.startPrank(guardian);
    cashProxied.mint(address(this), 1);
    cashProxied.grantRole(cashProxied.TRANSFER_ROLE(), address(this));
    vm.stopPrank();

    // Transfer to alice
    cashProxied.transfer(alice, 1);
    assertEq(cashProxied.balanceOf(alice), 1);
    assertEq(cashProxied.balanceOf(address(this)), 0);
  }

  function test_unit_cashToken_transfer_withTransferRole_allowance() public {
    // Mint to Alice and grant TRANSFER_ROLE to current contract
    vm.startPrank(guardian);
    cashProxied.mint(alice, 1);
    cashProxied.grantRole(cashProxied.TRANSFER_ROLE(), address(this));
    vm.stopPrank();

    // Approve current contract to transfer from Alice
    vm.prank(alice);
    cashProxied.approve(address(this), 1);

    // Transfer from Alice to current contract
    cashProxied.transferFrom(alice, address(this), 1);
    assertEq(cashProxied.balanceOf(alice), 0);
    assertEq(cashProxied.balanceOf(address(this)), 1);
  }

  function test_unit_cashToken_transfer_fail_noTransferRole() public {
    // Mint to current contract
    vm.prank(guardian);
    cashProxied.mint(address(this), 1);

    // Expect Revert
    vm.expectRevert("Cash: must have TRANSFER_ROLE to transfer");
    cashProxied.transfer(alice, 1);
  }

  // Tests that Cash contract reverts on pause before transfer if address doesn't have TRANSFER_ROLE
  function test_unit_cashToken_transfer_fail_pauseBeforeTransferRole() public {
    // Mint to current contract
    vm.startPrank(guardian);
    cashProxied.mint(address(this), 1);

    // Pause
    cashProxied.pause();
    vm.stopPrank();

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashProxied.transfer(alice, 1);
  }
}
