import { BigNumber } from "ethers";
import { parseUnits } from "ethers/lib/utils";
import { keccak256 } from "ethers/lib/utils";

export const PROD_GUARDIAN = "";
export const PROD_PAUSER = "";
export const PROD_ASSET_RECIPIENT = "";
export const PROD_FEE_RECIPIENT = "";
export const PROD_ASSET_SENDER = "";
export const PROD_USDC_ADDRESS = "";
export const MINT_LIMIT = parseUnits("10000", 6); // mint limit
export const REDEEM_LIMIT = parseUnits("10000", 18); // redeem limit
export const EPOCH_DURATION = BigNumber.from(86400); // epoch duration seconds
export const SANCTIONS_ORACLE = "0x40c57923924b5c5c5455c48d93317139addac8fb";
export const KYC_GROUP_CASH_SENDER_RECEIVER = BigNumber.from(1);
export const KYC_GROUP_1_HASH = keccak256(Buffer.from("KYC_GROUP_1", "utf-8"));
export const KYC_GROUP_CASH_SENDER = BigNumber.from(2);
export const KYC_GROUP_2_HASH = keccak256(Buffer.from("KYC_GROUP_2", "utf-8"));
export const KYC_GROUP_CASH = BigNumber.from(3);
