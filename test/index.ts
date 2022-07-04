import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { expandTo18Decimals,expandTo16Decimals ,mineBlocks } from "./utilities/utilities";
import { MyToken, MyTokenMod, MyTokenMod__factory, MyToken__factory, Token, Token__factory } from "../typechain";

describe("Token", function() {
  let token: MyToken;
  let staking: Token;
  let reward: MyTokenMod;
  let owner: SignerWithAddress;
  let signers: SignerWithAddress[];

  beforeEach(async()=>{
    signers = await ethers.getSigners();
    owner = signers[0];
    token = await new MyToken__factory(owner).deploy();
    reward = await new MyTokenMod__factory(owner).deploy();
    staking = await new Token__factory(owner).deploy(1000, token.address, reward.address);
  })

  it("successfully deploys the MyToken contract", async()=>{
    expect(await token.connect(signers[1]).owner()).to.be.equal(owner.address);
  });
  it("successfully deploys the reward contract.", async()=>{
    expect(await reward.connect(owner).owner()).to.be.equal(owner.address);
  })
  it("successfully deploys the staking contract using token's and reward's instance", async()=> {
    expect(await staking.connect(owner).admin()).to.be.equal(owner.address);
  });
  it("can add a stakeholder",async () => {
    await staking.connect(owner).addStakeholder(signers[1].address);
    expect(await staking.connect(owner).isStakeholder(signers[1].address)).to.be.not.equal(false);
  });
  it("can remove a stakeholder properly", async()=>{
    await staking.connect(owner).addStakeholder(signers[1].address);
    await staking.connect(signers[1]).removeStakeholder(signers[1].address);
    expect(await staking.connect(owner).isStakeholder(signers[1].address)).to.be.equal(false);
  });
  it("can stake the tokens", async()=>{
    await staking.connect(owner).addStakeholder(signers[1].address);
    await token.connect(owner).mint(owner.address, 1000);
    await token.connect(signers[1]).approve(staking.address, expandTo18Decimals(5));
    await token.connect(owner).mint(signers[1].address, expandTo18Decimals(5));
    await staking.connect(signers[1]).stake(expandTo18Decimals(5));
    await token.connect(owner).mint(staking.address, expandTo18Decimals(100));
    await staking.connect(signers[1]).unStake();
    expect(await staking.connect(owner).balanceOf(signers[1].address)).to.be.not.equal(2);
  });
  it("can give the right amount of loss to the stakers", async()=>{
    await staking.connect(owner).addStakeholder(signers[1].address);
    await token.connect(owner).mint(owner.address, 1000);
    await token.connect(signers[1]).approve(staking.address, expandTo18Decimals(5));
    await token.connect(owner).mint(signers[1].address, expandTo18Decimals(5));
    await staking.connect(signers[1]).stake(expandTo18Decimals(5));
    await token.connect(owner).mint(staking.address, expandTo18Decimals(100));
    await staking.connect(signers[1]).unStake();
    expect(await token.balanceOf(signers[1].address)).to.be.equal(expandTo16Decimals(450));
    // console.log("Balance of staker after taking benefits is: "+ await )
  });
  it("can return the same amount of tokens of staking type if maturity is reached.", async()=>{
    await staking.connect(owner).addStakeholder(signers[1].address);
    await token.connect(owner).mint(owner.address, 1000);
    await token.connect(signers[1]).approve(staking.address, expandTo18Decimals(6));
    await token.connect(owner).mint(signers[1].address, expandTo18Decimals(5));
    await staking.connect(signers[1]).stake(expandTo18Decimals(5));
    await token.connect(owner).mint(staking.address, expandTo18Decimals(100));
    await reward.connect(owner).mint(staking.address, expandTo18Decimals(100));
    await mineBlocks(ethers.provider, 1000);
    await staking.connect(signers[1]).unStake();
    expect(await token.balanceOf(signers[1].address)).to.be.equal(expandTo18Decimals(5));
  });
  it("can give the right amount of reward tokens to the stakeholder.", async()=>{
    await staking.connect(owner).addStakeholder(signers[1].address);
    await token.connect(owner).mint(owner.address, 1000);
    await token.connect(signers[1]).approve(staking.address, expandTo18Decimals(6));
    await token.connect(owner).mint(signers[1].address, expandTo18Decimals(5));
    await staking.connect(signers[1]).stake(expandTo18Decimals(5));
    await token.connect(owner).mint(staking.address, expandTo18Decimals(100));
    await reward.connect(owner).mint(staking.address, expandTo18Decimals(100));
    await mineBlocks(ethers.provider, 100);
    await staking.connect(signers[1]).unStake();
    expect(await reward.balanceOf(signers[1].address)).to.be.equal(expandTo16Decimals(30));
  });
  it("will not stake if OffStaking gets called correctly.", async()=>{
    await staking.connect(owner).addStakeholder(signers[1].address);
    await token.connect(owner).mint(owner.address, 1000);
    await token.connect(signers[1]).approve(staking.address, expandTo18Decimals(6));
    await token.connect(owner).mint(signers[1].address, expandTo18Decimals(5));
    await mineBlocks(ethers.provider, 500);
    await staking.connect(owner).OffStaking();
    await expect ( staking.connect(signers[1]).stake(expandTo18Decimals(5))).to.be.revertedWith("Owner has closed the staking option for now.");
    // await token.connect(owner).mint(staking.address, expandTo18Decimals(100));
    // await reward.connect(owner).mint(staking.address, expandTo18Decimals(100));
    // await mineBlocks(ethers.provider, 100);
    // await staking.connect(signers[1]).unStake();
  });
  it.only("will reward extra only to the top staker.", async()=>{
    await staking.connect(owner).addStakeholder(signers[1].address);
    await staking.connect(owner).addStakeholder(signers[2].address);
    await token.connect(owner).mint(owner.address, 1000);
    await token.connect(signers[1]).approve(staking.address, expandTo18Decimals(10));
    await token.connect(signers[2]).approve(staking.address, expandTo18Decimals(10));
    await token.connect(owner).mint(signers[1].address, expandTo18Decimals(10));
    await token.connect(owner).mint(signers[2].address, expandTo18Decimals(5));
    await staking.connect(signers[1]).stake(expandTo18Decimals(9));
    await staking.connect(signers[2]).stake(expandTo18Decimals(4));
    await token.connect(owner).mint(staking.address, expandTo18Decimals(100));
    await reward.connect(owner).mint(staking.address, expandTo18Decimals(100));
    await mineBlocks(ethers.provider, 100);
    await staking.connect(signers[1]).unStake();
    await staking.connect(signers[2]).unStake();
    console.log(await reward.balanceOf(signers[1].address));
    console.log(await reward.balanceOf(signers[2].address));
    expect(Number(await reward.balanceOf(signers[1].address))).to.be.greaterThan(Number(await reward.balanceOf(signers[2].address)));
  })
})