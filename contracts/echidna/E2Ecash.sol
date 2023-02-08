// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "contracts/echidna/setup.sol";

contract cashE2E is Setup_CashManager {
  constructor() {}

  /// @notice variables defined for moving state & invariant checks
  uint256 epochDeposited;

  uint256 totalSupplyBeforeClaim;
  uint256 totalSupplyAfterClaim;

  uint256 userCreditedBefore;
  uint256 userCreditedAfter;

  uint256 totalSupplyBeforeRedemptionRequest;
  uint256 totalSupplyAfterRedemptionRequest;

  uint256 quantityBurnedBefore;
  uint256 quantityBurnedAfter;

  uint256 epochRedemptionRequested;

  /// @notice Test to simulate a user requesting to mint Cash
  function RequestMint(uint256 _amount) public {
    userId = _amount % NUM_USERS;
    Account user = users[userId];
    // Pre-condition
    require(usdc.balanceOf(address(user)) > 0);
    uint256 amount = between(_amount, 1e6, usdc.balanceOf(address(user)));

    // Have the user approve the cashManager with some amt of usdc
    user.proxy(
      address(usdc),
      abi.encodeWithSelector(
        usdc.approve.selector,
        address(cashManager),
        amount
      )
    );

    // Have the user request to mint some amt of usdc for cash
    user.proxy(
      address(cashManager),
      abi.encodeWithSelector(cashManager.requestMint.selector, amount)
    );
    // Save the epoch they deposited during to state
    epochDeposited = cashManager.currentEpoch();
  }

  /// @notice Test to simulate the admin setting the exchange Rate
  function SetMintLimit() public {
    // Pre-condition
    require(cashManager.currentEpoch() > 0);
    cashManager.setMintExchangeRate(1e6, epochDeposited);
  }

  /// @notice Test to ensure that a user who requested can claim
  function UserClaimMint() public {
    Account user = users[userId];

    // Write info to state for invariant testing
    totalSupplyBeforeClaim = cashProxied.totalSupply();
    userCreditedBefore = cashManager.mintRequestsPerEpoch(
      epochDeposited,
      address(users[userId])
    );

    // Have the user claim their Cash tokens
    user.proxy(
      address(cashManager),
      abi.encodeWithSelector(
        cashManager.claimMint.selector,
        address(user),
        epochDeposited
      )
    );

    // Write info to state for invariant testing
    totalSupplyAfterClaim = cashProxied.totalSupply();
    userCreditedAfter = cashManager.mintRequestsPerEpoch(
      epochDeposited,
      address(users[userId])
    );
  }

  /// @notice Test to ensure that a user with cash can request a redemption
  function UserRequestRedemption(uint256 _amount) public {
    Account user = users[userId];

    // Pre-conditions
    require(cashProxied.balanceOf(address(user)) > 0);
    require(_amount > 1e6);

    // Need to transition to ensure the epoch is correct for pre call math
    cashManager.transitionEpoch();

    // Write info to state for invariant testing
    totalSupplyBeforeRedemptionRequest = cashProxied.totalSupply();
    quantityBurnedBefore = cashManager.getBurnedQuantity(
      cashManager.currentEpoch(),
      address(users[userId])
    );

    uint256 amount = between(
      _amount,
      1e6,
      cashProxied.balanceOf(address(user))
    );

    // Have the user approve cashManager some amt of cash
    user.proxy(
      address(cashProxied),
      abi.encodeWithSelector(
        cashProxied.approve.selector,
        address(cashManager),
        amount
      )
    );

    // Have the user request to withdraw some amt of cash
    user.proxy(
      address(cashManager),
      abi.encodeWithSelector(cashManager.requestRedemption.selector, amount)
    );

    // Write info to state for invariant testing
    totalSupplyAfterRedemptionRequest = cashProxied.totalSupply();
    quantityBurnedAfter = cashManager.getBurnedQuantity(
      cashManager.currentEpoch(),
      address(users[userId])
    );
  }

  /// @notice internal helper
  function between(
    uint256 val,
    uint256 lower,
    uint256 upper
  ) internal pure returns (uint256) {
    return lower + (val % (upper - lower + 1));
  }
}
