import { keccak256 } from "ethers/lib/utils";

export const MINTER_ROLE = keccak256(Buffer.from("MINTER_ROLE", "utf-8"));
export const PAUSER_ROLE = keccak256(Buffer.from("PAUSER_ROLE", "utf-8"));
export const TRANSFER_ROLE = keccak256(Buffer.from("TRANSFER_ROLE", "utf-8"));
export const SETTER_ADMIN = keccak256(Buffer.from("SETTER_ADMIN", "utf-8"));
export const DEFAULT_ADMIN_ROLE =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
// Official USDC Contract.
export const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
// Arbitrary account with large amount of USDC.
export const USDC_WHALE_ADDRESS = "0x55FE002aefF02F77364de339a1292923A15844B8";

export const SANCTIONS_ORACLE = "0x40c57923924b5c5c5455c48d93317139addac8fb";
