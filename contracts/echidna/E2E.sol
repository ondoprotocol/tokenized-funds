// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "contracts/echidna/E2Ecash.sol";

contract E2E is cashE2E {
  /**
   * @notice Invariant to test that there is never more cash than usdc deposited
   *
   * @dev This constraint will not hold in Prod, but should hold in tests
   */
  function echidna_CashIsBacked() external view returns (bool) {
    uint256 cashSupply = cashProxied.totalSupply();
    uint256 usdcDeposited = usdc.balanceOf(address(10)) +
      usdc.balanceOf(address(12));
    return (cashSupply <= usdcDeposited * 1e12);
  }

  /// @notice only true for 1:1 minting needs to be expanded otherwise
  function echidna_requestClaimIsValid() external view returns (bool) {
    uint256 diffSupply = totalSupplyAfterClaim - totalSupplyBeforeClaim;
    uint256 diffCredited = userCreditedBefore - userCreditedAfter;
    return (diffSupply / 1e12 == diffCredited);
  }

  /// @notice ensures that redemption requests are credited
  function echidna_requestRedemptionIsValid() external view returns (bool) {
    uint256 diffSupply = totalSupplyBeforeRedemptionRequest -
      totalSupplyAfterRedemptionRequest;
    uint256 creditedBurned = quantityBurnedAfter - quantityBurnedBefore;
    return (diffSupply == creditedBurned);
  }

  /// @notice Ensure that the rate is never set for the current epoch
  function echidna_rateNotSetForCurrent() external view returns (bool) {
    return (cashManager.epochToExchangeRate(cashManager.currentEpoch()) == 0);
  }

  /// @notice Ensures that the Redeem limit is respected
  function echidna_redeemLimitRespected() external view returns (bool) {
    uint256 epoch = cashManager.currentEpoch();
    uint256 burned = cashManager.redemptionInfoPerEpoch(epoch);
    return (burned <= cashManager.redeemLimit());
  }

  /// @notice Ensures that the exchange rate is never set for the current epoch
  function echidna_currentEpochRateIsAlwaysEQ0() external view returns (bool) {
    return (cashManager.epochToExchangeRate(cashManager.currentEpoch()) == 0);
  }

  /// @notice Dummy invariant to ensure that echidna is fuzzing states correctly
  // function echidna_shouldFail() external view returns (bool) {
  //     return (totalSupplyAfterRedemptionRequest == totalSupplyBeforeRedemptionRequest);
  // }
}
