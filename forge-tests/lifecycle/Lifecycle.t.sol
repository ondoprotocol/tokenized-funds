// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";
import "forge-std/console2.sol";

abstract contract TestCashLifeCycle is BasicDeployment {
  address[] toRedeem;
  address[] toRefund;
  uint256 totalDeposits;
  uint256 lastEpochSaved;

  /*//////////////////////////////////////////////////////////////
                            Unit Tests
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice tests that a single user is able to request mint and claim
   */
  function test_unit_request_and_claim() public {
    test_fuzz_request_and_claim(500e6);
  }

  /**
   * @notice tests Cash backing invariant assuming multiple users request to mint
   *         w/n the same epoch.
   */
  function test_unit_request_and_claim_multiple_users() public {
    test_fuzz_amount_request_and_claim_multiple_users(100e6);
  }

  /**
   * @notice Test for basic mint -> redeem logic
   */
  function test_unit_request_claim_redeem() public {
    test_fuzz_request_claim_redeem(500e6);
  }

  /**
   * @notice Example to cover scenarios in which multiple users:
   *      1) requestMint
   *      2) claimMint
   *      3) requestRedemption
   * This test ensures that users are airdropped collateral
   * corresponding to their respective ratio of collateral provided
   */
  function test_unit_request_claim_redeem_2_users() public {
    test_fuzz_request_claim_redeem_2_users(500e6, 1200e6);
  }

  /**
   * @notice Example to cover scenarios in which value accrual is discrete.
   *         Namely that interest is distributed to only those users who hold
   *         cash tokens prior to value being accrued to the NAV
   */
  function test_unit_value_accrues_to_correct_users() public {
    for (uint256 i = 0; i < 20; ++i) {
      seed_and_request_user(users[i], (i * 10e6) + 1e6);
    }

    vm.warp(block.timestamp + 1 days); // E0 -> E1
    cashManager.setMintExchangeRate(1e6, 0);

    for (uint256 i = 0; i < 20; ++i) {
      claim_mint_user(users[i], 0);
      assertEq(tokenProxied.balanceOf(users[i]), ((i * 10e6) + 1e6) * 1e12);
    }

    vm.warp(block.timestamp + 1 days); // E1 -> E2 (NAV constant)
    uint256 val;
    for (uint256 i = 0; i < 5; ++i) {
      val += (i * 10e6) + 1e6;
      toRedeem.push(users[i]);
      request_redemption_user(users[i], tokenProxied.balanceOf(users[i]));
    }
    vm.warp(block.timestamp + 1 days); // E2 (At end NAV double initial)-> E3
    serviceEpoch(toRedeem, toRefund, val * 2, 2);

    // Assert that each of these users received double their initial deposit
    for (uint256 i = 0; i < 5; ++i) {
      assertEq(usdc.balanceOf(users[i]), ((i * 10e6) + 1e6) * 2);
      vm.startPrank(users[i]);
      usdc.transfer(address(1), usdc.balanceOf(users[i]));
      vm.stopPrank();
    }

    // Have these 5 users deposit again in E3
    uint256 reinvested;
    for (uint256 i = 0; i < 5; ++i) {
      seed_and_request_user(users[i], (i * 10e6) + 1e6);
      reinvested += (i * 10e6) + 1e6;
      toRedeem.pop();
    }

    vm.warp(block.timestamp + 1 days); // E3 -> E4 (NAV constant)
    cashManager.setMintExchangeRate(2e6, 3);
    vm.prank(managerAdmin);
    cashManager.unpause();

    for (uint256 i = 0; i < 5; ++i) {
      claim_mint_user(users[i], 3);
      // Check that the amount of tokens minted in E3 correspond to new ER
      assertEq(
        tokenProxied.balanceOf(users[i]),
        (((i * 10e6) + 1e6) / 2) * 1e12
      );
    }

    val = 0;
    for (uint256 i = 5; i < 20; ++i) {
      val += (i * 10e6) + 1e6;
      toRedeem.push(users[i]);
      request_redemption_user(users[i], tokenProxied.balanceOf(users[i]));
    }
    for (uint256 i = 0; i < 5; ++i) {
      toRedeem.push(users[i]);
      request_redemption_user(users[i], tokenProxied.balanceOf(users[i]));
    }
    vm.warp(block.timestamp + 1 days); // E4 -> E5 (NAV constant)
    serviceEpoch(toRedeem, toRefund, val * 2 + reinvested, 4);
    for (uint256 i = 5; i < 20; ++i) {
      // Assert that users who owned cash @ time of value accrue
      // accrue value
      assertEq(usdc.balanceOf(users[i]), ((i * 10e6) + 1e6) * 2);
    }
    for (uint256 i = 0; i < 5; ++i) {
      // Assert that each of the 5 users who invested after value accrual get none
      assertEq(usdc.balanceOf(users[i]), ((i * 10e6) + 1e6));
    }
    assertEq(tokenProxied.totalSupply(), 0);
  }

  /**
   * @notice Example to cover scenarios in which users deposit during different
   *         Epochs. This test then asserts that each of these users who deposit at
   *         different times receive the correct amount of underlying at the time of
   *         redemption.
   */
  function test_unit_constant_accrual() public {
    test_fuzz_constant_accrual(100e6, 100e6);
  }

  /*//////////////////////////////////////////////////////////////
                            Fuzz Tests
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Test case to assert that users who request to mint different amounts w/n
   *         the same epoch receive the correct proportion of underlying assuming they
   *         redeem w/n the same epoch
   */
  function test_fuzz_request_claim_redeem_2_users(
    uint256 amount1,
    uint256 amount2
  ) public {
    vm.assume(amount1 > 1e6 && amount1 < usdc.balanceOf(address(this)));
    vm.assume(amount2 > 1e6 && amount2 < usdc.balanceOf(address(this)));
    vm.assume(amount1 + amount2 < 10_000e6);
    seed_and_request_user(users[1], amount1);
    seed_and_request_user(users[2], amount2);

    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);

    claim_mint_user(users[1], 0);
    claim_mint_user(users[2], 0);

    // Assert that the cashMinted is backed by deposits
    assertEq(
      usdc.balanceOf(assetRecipient) * 1e12,
      tokenProxied.balanceOf(users[1]) + tokenProxied.balanceOf(users[2])
    );

    request_redemption_user(users[1], tokenProxied.balanceOf(users[1]));
    request_redemption_user(users[2], tokenProxied.balanceOf(users[2]));

    vm.warp(block.timestamp + 1 days);
    toRedeem.push(users[1]);
    toRedeem.push(users[2]);
    serviceEpoch(toRedeem, toRefund, (amount1 + amount2) * 2, 1);

    uint256 expectedUser1 = (amount1 * (amount1 + amount2) * 2) /
      (amount1 + amount2);
    uint256 expectedUser2 = (amount2 * (amount1 + amount2) * 2) /
      (amount1 + amount2);

    // Assert that the users payout = payout *[(Their portion of cash) / (Total cash redeemed in E1)]
    assertEq(usdc.balanceOf(users[1]), expectedUser1);
    assertEq(usdc.balanceOf(users[2]), expectedUser2);
  }

  /**
   * @notice Tests that a user is able to claim and redeem an arbitrary collateral
   *         `amount` of cash tokens.
   */
  function test_fuzz_request_claim_redeem(uint256 amount) public {
    vm.assume(amount > 1e6 && amount < usdc.balanceOf(address(this)));
    vm.assume(amount < 1_000_000e6);

    seed_and_request_user(users[5], amount);
    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);
    claim_mint_user(users[5], 0);

    request_redemption_user(users[5], tokenProxied.balanceOf(users[5]));
    toRedeem.push(users[5]);
    vm.warp(block.timestamp + 1 days);
    serviceEpoch(toRedeem, toRefund, amount, 1);

    assertEq(usdc.balanceOf(users[5]), amount);
    assertEq(tokenProxied.balanceOf(users[5]), 0);
  }

  /**
   * @notice Test case to assert that multiple users are able to request and claim
   *         the correct amount of CASH corresponding to the amount they deposited
   */
  function test_fuzz_amount_request_and_claim_multiple_users(
    uint256 amount
  ) public {
    vm.assume(amount > 1e6 && amount < usdc.balanceOf(address(this)));
    vm.assume(amount < 100_000e6 / 10);
    for (uint256 i = 0; i < 10; ++i) {
      seed_and_request_user(users[i], (i * amount) + 100e6);
    }

    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);

    for (uint256 i = 0; i < 10; ++i) {
      claim_mint_user(users[i], 0);
      assertEq(tokenProxied.balanceOf(users[i]), ((i * amount) + 100e6) * 1e12);
    }
    // Require that all cash corresponds to deposits
    assertEq(tokenProxied.totalSupply(), usdc.balanceOf(assetRecipient) * 1e12);
  }

  /**
   * @notice Test case that a user is able to `requestMint` and `claimMint` for a
   *         given amount of collateral deposited
   */
  function test_fuzz_request_and_claim(uint256 amount) public {
    vm.assume(amount > 1e6 && amount < usdc.balanceOf(address(this)));
    vm.assume(amount < 1_000_000e6);
    seed_and_request_user(users[1], amount);
    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);
    claim_mint_user(users[1], 0);

    // Assert that the user has claimed their balance of cash
    assertEq(tokenProxied.balanceOf(users[1]), amount * 1e12);
    // Assert that the asset sender has all of their money
    assertEq(usdc.balanceOf(assetRecipient) * 1e12, tokenProxied.totalSupply());
    // Assert that the users balance has decreased
    assertEq(usdc.balanceOf(users[1]), 0);
  }

  /**
   * @notice Test case to ensure that groups of users who deposit w/n given
   *         epochs are credited different amounts of interest earned assuming
   *         that both of these groups of users `requestRedemption` w/n the same
   *         epoch
   */
  function test_fuzz_constant_accrual(uint64 amt1, uint64 amt2) public {
    vm.assume(amt1 >= 100e6 && amt1 < 50_000e6);
    vm.assume(amt2 >= 100e6 && amt2 < 50_000e6);
    for (uint256 i = 0; i < 10; ++i) {
      seed_and_request_user(users[i], amt1);
    }

    vm.warp(block.timestamp + 1 days); // E0 -> E1
    cashManager.setMintExchangeRate(1e6, 0);
    console.log("The nav at the end of E0", get_predetermined_nav());
    console.log("The current epoch is", cashManager.currentEpoch());

    // Have users 0-9 claim their tokens and credit their deposits to the account
    for (uint256 i = 0; i < 10; ++i) {
      claim_mint_user(users[i], 0);
      totalDeposits += uint256(amt1);
      // assertEq(tokenProxied.balanceOf(users[i]), amt1 * 1e12);
    }

    // Have users 10-14 request to deposit their money is in transit
    for (uint256 i = 10; i < 15; ++i) {
      seed_and_request_user(users[i], amt2);
    }

    // Move to the next epoch
    vm.warp(block.timestamp + 1 days); // E1 -> E2
    cashManager.transitionEpoch();
    // Accrue interest on money in the account
    get_predetermined_nav();
    // Determine the mint rate for users who requested to mint in E1
    uint256 rate = ((totalDeposits) * 1e18) / tokenProxied.totalSupply();
    console.log("The solved rate is", rate);
    cashManager.setMintExchangeRate(rate, 1);
    for (uint256 i = 10; i < 15; ++i) {
      claim_mint_user(users[i], 1);
      totalDeposits += amt2;
    }

    console.log("The current epoch is", cashManager.currentEpoch());
    console.log("The nav at this epoch", get_predetermined_nav());
    console.log("The total supply of cash", tokenProxied.totalSupply());

    // Fast forward 10 epochs
    for (uint256 i = 0; i < 10; ++i) {
      vm.warp(block.timestamp + 1 days);
      cashManager.transitionEpoch();
      get_predetermined_nav();
    }

    // Have all users request to redemption in Epoch 12
    for (uint256 i = 0; i < 15; ++i) {
      request_redemption_user(users[i], tokenProxied.balanceOf(users[i]));
      toRedeem.push(users[i]);
    }

    vm.warp(block.timestamp + 1 days);
    cashManager.transitionEpoch();
    console.log(
      "The epoch in which redemptions are serviced",
      cashManager.currentEpoch()
    );
    console.log(
      "The current nav @ time of redemption:",
      get_predetermined_nav()
    );
    serviceEpoch(toRedeem, toRefund, totalDeposits, 12);

    // Calculate the interest accrued to each user and assert that is ~1bps of the
    // value that they receive
    assertAlmostEqBps(
      usdc.balanceOf(users[1]),
      (_rpow(10010, 12, 1e4) * amt1) / 1e4,
      1
    );
    assertAlmostEqBps(
      usdc.balanceOf(users[11]),
      (_rpow(10010, 11, 1e4) * amt2) / 1e4,
      1
    );
  }

  /*//////////////////////////////////////////////////////////////
                                Helpers
    //////////////////////////////////////////////////////////////*/

  function request_redemption_user(address user, uint256 amountCash) public {
    vm.startPrank(address(user));
    tokenProxied.approve(address(cashManager), amountCash);
    cashManager.requestRedemption(amountCash);
    vm.stopPrank();
  }

  function serviceEpoch(
    address[] memory users,
    address[] memory _toRefund,
    uint256 amountToDist,
    uint256 epoch
  ) public {
    vm.prank(usdcWhale);
    usdc.transfer(assetSender, amountToDist);
    vm.startPrank(assetSender);
    usdc.approve(address(cashManager), amountToDist);
    vm.stopPrank();

    vm.prank(managerAdmin);
    cashManager.completeRedemptions(
      users,
      _toRefund, // no users to refund cash token
      amountToDist,
      epoch,
      0 // 0 fees
    );
  }

  function seed_and_request_user(address user, uint256 amount) public {
    usdc.transfer(user, amount);
    _addAddressToKYC(kycRequirementGroup, user);
    vm.startPrank(user);
    usdc.approve(address(cashManager), amount);
    cashManager.requestMint(amount);
    vm.stopPrank();
  }

  function claim_mint_user(address user, uint256 epoch) public {
    vm.prank(user);
    cashManager.claimMint(user, epoch);
  }

  function get_predetermined_nav() public returns (uint256) {
    if (cashManager.currentEpoch() - lastEpochSaved > 0) {
      totalDeposits =
        ((10010 * (cashManager.currentEpoch() - lastEpochSaved)) *
          totalDeposits) /
        1e4;
      lastEpochSaved = cashManager.currentEpoch();
      return totalDeposits;
    } else {
      return totalDeposits;
    }
  }

  uint256 private constant ONE = 10 ** 27;

  // Copied from https://github.com/makerdao/dss/blob/master/src/jug.sol
  function _rpow(
    uint256 x,
    uint256 n,
    uint256 base
  ) internal pure returns (uint256 z) {
    assembly {
      switch x
      case 0 {
        switch n
        case 0 {
          z := base
        }
        default {
          z := 0
        }
      }
      default {
        switch mod(n, 2)
        case 0 {
          z := base
        }
        default {
          z := x
        }
        let half := div(base, 2) // for rounding.
        for {
          n := div(n, 2)
        } n {
          n := div(n, 2)
        } {
          let xx := mul(x, x)
          if iszero(eq(div(xx, x), x)) {
            revert(0, 0)
          }
          let xxRound := add(xx, half)
          if lt(xxRound, xx) {
            revert(0, 0)
          }
          x := div(xxRound, base)
          if mod(n, 2) {
            let zx := mul(z, x)
            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
              revert(0, 0)
            }
            let zxRound := add(zx, half)
            if lt(zxRound, zx) {
              revert(0, 0)
            }
            z := div(zxRound, base)
          }
        }
      }
    }
  }

  function _rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = _mul(x, y) / ONE;
  }

  function _mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }
}
