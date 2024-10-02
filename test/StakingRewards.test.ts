import { ethers } from "hardhat";
import { expect } from "chai";
import { StakingRewards, ERC20, ERC20Burnable } from "../typechain-types";

describe("StakingRewards", function () {
  let stakingRewards: StakingRewards;
  let rntToken: ERC20;
  let esRntToken: ERC20Burnable;
  let owner: any, user: any, otherUser: any;

  const initialRntSupply = ethers.utils.parseEther("10000"); // 初始化供应量
  const stakeAmount = ethers.utils.parseEther("100"); // 质押数量

  beforeEach(async function () {
    // 获取合约部署者和用户
    [owner, user, otherUser] = await ethers.getSigners();

    // 部署一个 ERC20 代币作为 RNT 代币
    const RNTToken = await ethers.getContractFactory("ERC20");
    rntToken = await RNTToken.deploy("RNT Token", "RNT");
    await rntToken.deployed();

    // 将部分 RNT 代币分配给用户
    await rntToken.mint(user.address, initialRntSupply);

    // 部署 StakingRewards 合约
    const StakingRewards = await ethers.getContractFactory("StakingRewards");
    stakingRewards = await StakingRewards.deploy(rntToken.address);
    await stakingRewards.deployed();

    // 获取合约内部的 esRNT 代币
    esRntToken = await ethers.getContractAt("ERC20Burnable", await stakingRewards.esRntToken());
  });

  describe("Staking functionality", function () {
    it("should allow a user to stake tokens", async function () {
      // 用户批准质押的 RNT 代币数量
      await rntToken.connect(user).approve(stakingRewards.address, stakeAmount);

      // 用户质押 RNT 代币
      await stakingRewards.connect(user).stake(stakeAmount);

      // 验证合约中存储的质押信息
      const stakeInfo = await stakingRewards.stakes(user.address);
      expect(stakeInfo.amount).to.equal(stakeAmount);
    });

    it("should emit an event when a user stakes tokens", async function () {
      await rntToken.connect(user).approve(stakingRewards.address, stakeAmount);
      await expect(stakingRewards.connect(user).stake(stakeAmount))
        .to.emit(stakingRewards, "Staked")
        .withArgs(user.address, stakeAmount);
    });
  });

  describe("Unstaking functionality", function () {
    it("should allow a user to unstake and transfer back tokens", async function () {
      // 先质押
      await rntToken.connect(user).approve(stakingRewards.address, stakeAmount);
      await stakingRewards.connect(user).stake(stakeAmount);

      // 取消质押
      await stakingRewards.connect(user).unstake();

      // 验证用户 RNT 余额恢复
      const userBalance = await rntToken.balanceOf(user.address);
      expect(userBalance).to.equal(initialRntSupply);
    });

    it("should emit an event when a user unstakes tokens", async function () {
      await rntToken.connect(user).approve(stakingRewards.address, stakeAmount);
      await stakingRewards.connect(user).stake(stakeAmount);

      await expect(stakingRewards.connect(user).unstake())
        .to.emit(stakingRewards, "Unstaked")
        .withArgs(user.address, stakeAmount);
    });
  });

  describe("Reward functionality", function () {
    it("should calculate rewards correctly", async function () {
      // 质押代币
      await rntToken.connect(user).approve(stakingRewards.address, stakeAmount);
      await stakingRewards.connect(user).stake(stakeAmount);

      // 模拟时间流逝 (加速时间)
      const oneDay = 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [oneDay]); // 增加一天
      await ethers.provider.send("evm_mine", []); // 强制挖矿一个新块

      // 检查奖励
      const reward = await stakingRewards.calculateReward(user.address);
      expect(reward).to.equal(ethers.utils.parseEther("1")); // 每天1个esRNT
    });

    it("should allow a user to claim rewards", async function () {
      await rntToken.connect(user).approve(stakingRewards.address, stakeAmount);
      await stakingRewards.connect(user).stake(stakeAmount);

      const oneDay = 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [oneDay]);
      await ethers.provider.send("evm_mine", []);

      await stakingRewards.connect(user).claimReward();

      const esRntBalance = await esRntToken.balanceOf(user.address);
      expect(esRntBalance).to.equal(ethers.utils.parseEther("1"));
    });
  });

  describe("Convert esRNT to RNT", function () {
    it("should allow a user to convert esRNT to RNT", async function () {
      await rntToken.connect(user).approve(stakingRewards.address, stakeAmount);
      await stakingRewards.connect(user).stake(stakeAmount);

      const oneDay = 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [oneDay]);
      await ethers.provider.send("evm_mine", []);

      await stakingRewards.connect(user).claimReward();

      const esRntAmount = await esRntToken.balanceOf(user.address);

      await stakingRewards.connect(user).convertEsRntToRnt(esRntAmount);

      const finalRntBalance = await rntToken.balanceOf(user.address);
      expect(finalRntBalance).to.be.gt(stakeAmount);
    });
  });
});
