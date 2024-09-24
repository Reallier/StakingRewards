// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingRewards is Ownable {
    IERC20 public rntToken;
    ERC20Burnable public esRntToken;

    uint256 public constant DAILY_REWARD = 1 ether; // 每天1个esRNT
    uint256 public constant LOCK_PERIOD = 30 days; // 锁定期为30天

    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    mapping(address => Stake) private stakes;
    mapping(address => uint256) private rewards;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _rntToken) {
        rntToken = IERC20(_rntToken);
        esRntToken = new ERC20Burnable();
        esRntToken.mint(msg.sender, 0); // 初始化esRNT代币
    }

    function stake(uint256 _amount) external {
        require(_amount > 0, "Stake amount must be greater than zero");
        require(rntToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        if (stakes[msg.sender].amount > 0) {
            claimReward(); // 先领取未领取的奖励
        }
        
        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].startTime = block.timestamp;

        emit Staked(msg.sender, _amount);
    }

    function unstake() external {
        require(stakes[msg.sender].amount > 0, "No staked tokens to withdraw");

        claimReward(); // 领取所有未领取的奖励
        
        uint256 amountToWithdraw = stakes[msg.sender].amount;
        stakes[msg.sender].amount = 0;

        require(rntToken.transfer(msg.sender, amountToWithdraw), "Transfer failed");

        emit Unstaked(msg.sender, amountToWithdraw);
    }

    function claimReward() public {
        require(stakes[msg.sender].amount > 0, "No staked tokens");

        uint256 rewardAmount = calculateReward(msg.sender);
        if (rewardAmount > 0) {
            rewards[msg.sender] += rewardAmount;
            esRntToken.mint(msg.sender, rewardAmount);

            emit RewardClaimed(msg.sender, rewardAmount);
        }
    }

    function calculateReward(address _user) public view returns (uint256) {
        if (stakes[_user].amount == 0) return 0;

        uint256 timePassed = block.timestamp - stakes[_user].startTime;
        uint256 reward = (timePassed * stakes[_user].amount * DAILY_REWARD) / 1 days;
        return reward - rewards[_user];
    }

    function convertEsRntToRnt(uint256 _amount) external {
        require(esRntToken.balanceOf(msg.sender) >= _amount, "Insufficient esRNT balance");
        
        uint256 unlockedAmount = (_amount * (block.timestamp - stakes[msg.sender].startTime)) / LOCK_PERIOD;
        require(unlockedAmount > 0, "All tokens are still locked");

        if (unlockedAmount < _amount) {
            // 如果有锁定部分，则燃烧锁定部分
            esRntToken.burn(_amount - unlockedAmount);
            _amount = unlockedAmount;
        }

        esRntToken.burnFrom(msg.sender, _amount);
        rntToken.transfer(msg.sender, _amount);
    }
}