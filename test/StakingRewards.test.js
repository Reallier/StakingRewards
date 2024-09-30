const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingRewards", function () {
  let RNT, rntToken, esRNT, stakingRewards;
  let owner, addr1, addr2;
  const INITIAL_SUPPLY = ethers.utils.parseEther("1000"); // 1000 RNT
  const DAILY_REWARD = ethers.utils.parseEther("1"); // 每天1个esRNT
  const LOCK_PERIOD = 30 * 24 * 60 * 60; // 30天

  beforeEach(async function () {
    // 获取账户
    [owner, addr1, addr2] = await ethers.getSigners();

    // 部署自定义的 RNT 代币（ERC20）
    const RNT = await ethers.getContractFactory("ERC20");
    rntToken = await RNT.deploy("RNT Token", "RNT");
    await rntToken.deployed();

    // 给 addr1 和 addr2 一些初始代币
    await rntToken.mint(addr1.address, INITIAL_SUPPLY);
    await rntToken.mint(addr2.address, INITIAL_SUPPLY);

    // 部署 StakingRewards 合约
    const StakingRewards = await ethers.getContractFactory("StakingRewards");
    stakingRewards = await StakingRewards.deploy(rntToken.address);
    await stakingRewards.deployed();

    // addr1 和 addr2 授权 StakingRewards 合约提取 RNT 代币
    await rntToken.connect(addr1).approve(stakingRewards.address, INITIAL_SUPPLY);
    await rntToken.connect(addr2).approve(stakingRewards.address, INITIAL_SUPPLY);
  });

  it("用户可以质押 RNT", async function () {
    const stakeAmount = ethers.utils.parseEther("100");

    await stakingRewards.connect(addr1).stake(stakeAmount);
    const stakeInfo = await stakingRewards.stakes(addr1.address);

    expect(stakeInfo.amount).to.equal(stakeAmount);
  });

  it("用户可以领取奖励 esRNT", async function () {
    const stakeAmount = ethers.utils.parseEther("100");

    // 质押100 RNT
    await stakingRewards.connect(addr1).stake(stakeAmount);

    // 快进时间1天
    await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    // 领取奖励
    await stakingRewards.connect(addr1).claimReward();

    const rewardBalance = await stakingRewards.esRntToken().balanceOf(addr1.address);
    expect(rewardBalance).to.equal(DA
