import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signers";
import { BigNumber, BigNumberish, Signer } from "ethers";
import { ethers, network } from "hardhat";
import { ERC20 } from "../../typechain";
import { USDC_ADDRESS } from "./constants";

export const increaseBlockTimestamp = async (seconds: number, mine = false) => {
  await network.provider.send("evm_increaseTime", [Math.floor(seconds)]);
  if (mine) {
    await network.provider.send("evm_mine", []);
  }
};

export const getImpersonatedSigner = async (
  account: string
): Promise<SignerWithAddress> => {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [account],
  });
  return ethers.getSigner(account);
};

export const setUSDCBalance = async (
  signer: SignerWithAddress,
  usdcWhale: SignerWithAddress,
  balance: BigNumberish
) => {
  const usdcContract: ERC20 = await ethers.getContractAt("ERC20", USDC_ADDRESS);
  const originalBalance = await usdcContract.balanceOf(signer.address);
  // Do nothing if signer already has correct balance.
  if (originalBalance.eq(balance)) return;

  // If the signer has more USDC than balance param,
  // send the necessary amount to the whale address.
  if (originalBalance.gt(balance)) {
    await usdcContract
      .connect(signer)
      .transfer(usdcWhale.address, originalBalance.sub(balance));
    return;
  }
  // If the signer has less USDC than balance param, send the difference
  // to the signer from the "impersonated" whale.
  await usdcContract
    .connect(usdcWhale)
    .transfer(signer.address, BigNumber.from(balance).sub(originalBalance));
};
