pragma solidity 0.8.16;

contract TestCashManagerEvents {
  event Mint(
    address indexed sender,
    uint256 indexed epoch,
    uint256 collateralAmountIn,
    uint256 collateralAmountOut,
    uint256 feesInCollateral,
    uint256 cashAmountOut
  );

  event MintRequested(
    address indexed client,
    uint256 indexed epoch,
    uint256 collateralDeposited,
    uint256 depositValueAfterFees,
    uint256 feesInCollateral
  );

  event MintCompleted(
    address indexed user,
    uint256 cashAmountOut,
    uint256 collateralAmountDeposited,
    uint256 exchangeRate,
    uint256 indexed epochClaimedFrom
  );

  event FeeRecipientSet(address oldFeeRecipient, address newFeeRecipient);

  event AssetRecipientSet(address oldAssetRecipient, address newAssetRecipient);

  event AssetSenderSet(address oldAssetSender, address newAssetSender);

  event MinimumDepositAmountSet(uint256 oldMinimum, uint256 newMinimum);

  event MinimumRedeemAmountSet(uint256 oldRedeemMin, uint256 newRedeemMin);

  event MintFeeSet(uint256 oldFee, uint256 newFee);

  event MintExchangeRateSet(
    uint256 indexed epoch,
    uint256 oldRate,
    uint256 newRate
  );

  event ExchangeRateDeltaLimitSet(uint256 oldLimit, uint256 newLimit);

  event MintExchangeRateCheckFailed(
    uint256 indexed epoch,
    uint256 lastEpochRate,
    uint256 newRate
  );

  event MintExchangeRateOverridden(
    uint256 indexed epoch,
    uint256 oldRate,
    uint256 newRate,
    uint256 lastSetMintExchangeRate
  );

  event MintLimitSet(uint256 oldLimit, uint256 newLimit);

  event RedeemLimitSet(uint256 oldLimit, uint256 newLimit);

  event EpochDurationSet(uint256 oldDuration, uint256 newDuration);

  event RedemptionRequested(
    address indexed user,
    uint256 cashAmountIn,
    uint256 indexed epoch
  );

  event RedemptionCompleted(
    address indexed user,
    uint256 cashAmountRequested,
    uint256 collateralAmountReturned,
    uint256 indexed epoch
  );

  event RefundIssued(
    address indexed user,
    uint256 cashAmountOut,
    uint256 indexed epoch
  );

  event Paused(address account);

  event Unpaused(address account);

  event PendingRedemptionBalanceSet(
    address indexed user,
    uint256 indexed epoch,
    uint256 balance,
    uint256 totalBurned
  );

  event PendingMintBalanceSet(
    address indexed user,
    uint256 indexed epoch,
    uint256 oldBalance,
    uint256 newBalance
  );
}
