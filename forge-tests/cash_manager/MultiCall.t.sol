// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";
import "contracts/interfaces/IMulticall.sol";

contract TestMultiCall is BasicDeployment {
  // Sourced from contracts/external/openzeppelin/contracts/token/IERC20.sol
  bytes4 private constant FUNC_SELECTOR =
    bytes4(keccak256("transfer(address,uint256)"));
  IMulticall.ExCallData[] functors;

  function setUp() public {
    createDeploymentCash();
    delete functors;

    vm.startPrank(managerAdmin);
    cashManager.grantRole(cashManager.MANAGER_ADMIN(), address(this));
    cashManager.grantRole(cashManager.SETTER_ADMIN(), address(this));
    vm.stopPrank();

    vm.prank(pauser);
    cashManager.pause();

    // Seed the cash manager contract with USDC. This should not happen in
    // normal operation.
    vm.prank(usdcWhale);
    usdc.transfer(address(cashManager), INIT_BALANCE_USDC);
  }

  function addTransferToFunctors() private {
    // Transfer 1 USDC to Alice.
    bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR, alice, 1e6);
    IMulticall.ExCallData memory functor;
    functor.data = data;
    functor.target = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    functors.push(functor);
  }

  function test_successful_return() public {
    assertEq(usdc.balanceOf(address(cashManager)), INIT_BALANCE_USDC);
    addTransferToFunctors();
    vm.prank(managerAdmin);
    bytes[] memory result = cashManager.multiexcall(functors);
    assertEq(usdc.balanceOf(address(cashManager)), INIT_BALANCE_USDC - 1e6);
    assertEq(usdc.balanceOf(address(alice)), 1e6);
    assertEq(result.length, 1);
    assertEq(uint256(bytes32(result[0])), 1);
  }

  function test_wrong_caller() public {
    assertEq(usdc.balanceOf(address(cashManager)), INIT_BALANCE_USDC);
    addTransferToFunctors();
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.multiexcall(functors);
  }

  function test_not_paused() public {
    assertEq(usdc.balanceOf(address(cashManager)), INIT_BALANCE_USDC);
    addTransferToFunctors();
    vm.startPrank(managerAdmin);
    cashManager.unpause();
    vm.expectRevert("Pausable: not paused");
    cashManager.multiexcall(functors);
    vm.stopPrank();
  }
}
