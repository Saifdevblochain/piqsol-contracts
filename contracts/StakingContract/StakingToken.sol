// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingContract is
    Initializable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    // using SafeMathUpgradeable for uint256;

    /* ========== STATE VARIABLES ========== */
    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    uint256 public minStake;

    mapping(address => uint256) public rewards;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    address public ownerAddress;
    uint256 public AllrewardTokens;

    /* ==========struct ========== */
    struct Stake {
        uint256 stakeTime;
        uint256 withdrawTime;
        uint256 amount;
        uint256 bonus;
        uint256 plan;
        bool withdrawan;
        bool rewardGet;
        uint256 allTime;
    }

    struct User {
        uint256 userTotalStaked;
        uint256 remainingStake;
        uint256 stakeCount;
        uint256 totalRewardTokens;
        mapping(uint256 => Stake) stakerecord;
    }

    mapping(address => User) public users;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    uint256[4] public durations;

    function initialize(
        address _rewardsToken,
        address _stakingToken
    ) public initializer {
        durations = [7 days, 30 days, 60 days, 120 days];
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        minStake = 1e18;
        ownerAddress = msg.sender;
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /*===========Events================-*/

    event UnStakeBeforeTimeCompletion(
        uint256 withdraTokenwAmount,
        address sender,
        address reciever
    );
    event UnstakeOnTimeCompletion(
        uint256 withdrawTokenAmount,
        uint256 rewardTokenAmount,
        address sender,
        address reciever
    );
    event StakeRecord(
        uint256 stakingCount,
        uint256 stakeAmount,
        uint256 stakingPlan,
        uint256 withDrawTime,
        uint256 rewardCalculations,
        address stakerAddress
    );
    event StakeCount(uint256 currentCount);

    /* ========== FUNCTIONS ========== */

    function staking(uint256 amount, uint256 plan) external nonReentrant {
        require(plan >= 0 && plan < 4, "put valid plan details");
        require(
            amount > minStake,
            "cant deposit need to stake more than minimum amount"
        );
        require(msg.sender != address(0), "User address canot be zero.");
        require(ownerAddress != address(0), "Owner address canot be zero.");

        User storage user = users[msg.sender];

        user.stakeCount++;
        stakingToken.transferFrom(msg.sender, ownerAddress, amount);
        user.userTotalStaked += amount;
        user.remainingStake += amount;
        user.stakerecord[user.stakeCount].plan = plan;
        user.stakerecord[user.stakeCount].stakeTime = block.timestamp;
        user.stakerecord[user.stakeCount].amount = amount;
        user.stakerecord[user.stakeCount].withdrawTime =
            block.timestamp +
            (durations[plan]);
        user.stakerecord[user.stakeCount].bonus = rewardCalculate(plan);

        _totalSupply = _totalSupply + (amount);
        _balances[msg.sender] = _balances[msg.sender] + (amount);

        emit StakeRecord(
            user.stakeCount,
            user.stakerecord[user.stakeCount].amount,
            user.stakerecord[user.stakeCount].plan,
            user.stakerecord[user.stakeCount].withdrawTime,
            user.stakerecord[user.stakeCount].bonus,
            msg.sender
        );
    }

    function withdraw(uint256 count) public {
        User storage user = users[msg.sender];
        require(user.stakeCount >= count, "Invalid Stake index");
        require(!user.stakerecord[count].withdrawan, " withdraw completed ");
        require(msg.sender != address(0), "User address canot be zero.");
        require(ownerAddress != address(0), "owner address canot be zero.");

        if (block.timestamp >= user.stakerecord[count].withdrawTime) {
            stakingToken.transferFrom(
                ownerAddress,
                msg.sender,
                user.stakerecord[count].amount
            );
            rewardsToken.transferFrom(
                ownerAddress,
                msg.sender,
                user.stakerecord[count].bonus
            );
            user.totalRewardTokens += user.stakerecord[count].bonus;

            AllrewardTokens += user.stakerecord[count].bonus;
        } else {
            stakingToken.transferFrom(
                ownerAddress,
                msg.sender,
                user.stakerecord[count].amount
            );
        }

        user.remainingStake -= user.stakerecord[user.stakeCount].amount;
        user.stakerecord[count].withdrawan = true;

        emit StakeCount(count);
    }

    function rewardCalculate(uint256 plan) public view returns (uint256 mm) {
        User storage user = users[msg.sender];
        if (plan == 0) {
            return
                calculateReward(user.stakerecord[user.stakeCount].amount, 475);
        } else if (plan == 1) {
            return
                calculateReward(user.stakerecord[user.stakeCount].amount, 675);
        } else if (plan == 2) {
            return
                calculateReward(user.stakerecord[user.stakeCount].amount, 875);
        } else if (plan == 3) {
            return
                calculateReward(user.stakerecord[user.stakeCount].amount, 975);
        }
    }

    function calculateReward(
        uint256 _amount,
        uint256 percentage
    ) public pure returns (uint256) {
        return (_amount * percentage) / 10000;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
