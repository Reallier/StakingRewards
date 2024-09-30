// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // ERC20代币接口
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol"; // 可销毁的ERC20代币扩展
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // 基础的ERC20代币实现
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // 防重入攻击保护
import "@openzeppelin/contracts/access/Ownable.sol"; // 合约所有权管理

// 继承自ReentrancyGuard和Ownable
contract StakingRewards is ReentrancyGuard, Ownable {
    IERC20 public rntToken; // RNT代币接口
    ERC20Burnable public esRntToken;  // 可销毁的esRNT代币接口

    uint256 public constant DAILY_REWARD = 1 ether; // 每天1个esRNT
    uint256 public constant LOCK_PERIOD = 30 days; // 锁定期为30天

    // 用户的质押信息
    struct Stake {
        uint256 amount; // 质押数量
        uint256 startTime; // 质押开始时间
    }

    // 用户地址到质押信息的映射
    mapping(address => Stake) private stakes;
    // 用户地址到奖励的映射
    mapping(address => uint256) private rewards;

    event Staked(address indexed user, uint256 amount); // 质押事件
    event Unstaked(address indexed user, uint256 amount); // 取消质押事件
    event RewardClaimed(address indexed user, uint256 amount); // 领取奖励事件

    // 构造函数，初始化RNT代币和esRNT代币
    constructor(address _rntToken) {
        rntToken = IERC20(_rntToken);
        esRntToken = new ERC20Burnable("esRNT", "esRNT");
    }

    // 质押函数，用户质押RNT代币
    function stake(uint256 _amount) external nonReentrant {
        // 确保质押数量大于0
        require(_amount > 0, "Stake amount must be greater than zero");
        // 确保用户有足够的RNT代币
        require(rntToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        // 如果用户已经质押过，先领取未领取的奖励
        if (stakes[msg.sender].amount > 0) {
            claimReward(); // 先领取未领取的奖励
        }

        // 更新质押信息
        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].startTime = block.timestamp;

        // 触发质押事件
        emit Staked(msg.sender, _amount);
    }

    // 取消质押函数，用户取消质押并领取奖励
    function unstake() external nonReentrant {
        // 确保用户有质押记录
        require(stakes[msg.sender].amount > 0, "No staked tokens to withdraw");

        claimReward(); // 领取所有未领取的奖励
        
        // 提取质押金额, 重置质押信息
        uint256 amountToWithdraw = stakes[msg.sender].amount;
        stakes[msg.sender].amount = 0;

        // 确保将RNT代币转移回用户账户成功
        require(rntToken.transfer(msg.sender, amountToWithdraw), "Transfer failed");

        // 触发取消质押事件
        emit Unstaked(msg.sender, amountToWithdraw);
    }

    // 领取奖励函数，用户领取奖励
    function claimReward() public nonReentrant {
        // 确保用户有质押记录
        require(stakes[msg.sender].amount > 0, "No staked tokens");

        // 计算奖励金额
        uint256 rewardAmount = calculateReward(msg.sender);
        if (rewardAmount > 0) { // 如果有奖励可领取
            rewards[msg.sender] += rewardAmount; // 累加奖励
            esRntToken.mint(msg.sender, rewardAmount); // 发行esRNT奖励给用户

            stakes[msg.sender].startTime = block.timestamp; // 更新质押时间
            emit RewardClaimed(msg.sender, rewardAmount); // 触发领取奖励事件
        }
    }

    // 计算用户应得奖励的功能
    function calculateReward(address _user) public view returns (uint256) {
        // 如果用户没有质押记录，则返回0
        if (stakes[_user].amount == 0) return 0;

        uint256 timePassed = block.timestamp - stakes[_user].startTime; // 计算已过的时间
        uint256 reward = (timePassed * stakes[_user].amount * DAILY_REWARD) / 1 days; // 根据时间计算奖励
        // 返回实际应得奖励（扣除已领取的部分）
        return reward - rewards[_user];
    }

    // 将esRNT转换成RNT的功能
    function convertEsRntToRnt(uint256 _amount) external nonReentrant {
        // 确保用户有足够的esRNT余额
        require(esRntToken.balanceOf(msg.sender) >= _amount, "Insufficient esRNT balance");
        
        // 计算质押时间
        uint256 stakedTime = block.timestamp - stakes[msg.sender].startTime;
        // 计算解锁的数量
        uint256 unlockedAmount = (_amount * stakedTime) / LOCK_PERIOD;

        // 确保不是全部还在锁定期
        require(unlockedAmount > 0, "All tokens are still locked");

        // 如果解锁的数量小于请求的数量，则燃烧锁定部分
        if (unlockedAmount < _amount) {
            esRntToken.burn(_amount - unlockedAmount); // 燃烧锁定部分
            _amount = unlockedAmount;
        }

        // 燃烧esRNT，并将相应数量的RNT转移给用户
        esRntToken.burnFrom(msg.sender, _amount);
        rntToken.transfer(msg.sender, _amount);
    }
}
