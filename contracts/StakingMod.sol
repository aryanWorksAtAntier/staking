pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Token.sol";
import "./RewardToken.sol";
import "hardhat/console.sol";


contract Token is MyTokenMod {
    address public admin;
    IERC20 public contractAddress;
    IERC20 public rewardContractAddress;
    uint lastStakedTime;
    bool canStake;

    constructor(uint initialSupply, address _contractAddress, address _rewardContractAddress) public{
        admin = msg.sender;
        _mint(msg.sender, initialSupply);
        contractAddress = IERC20(_contractAddress);
        rewardContractAddress = IERC20(_rewardContractAddress);
        lastStakedTime = block.timestamp;
        canStake = true;
        //here we initialized it in the constructor, if someone doesn't stake for 5 minutes after the lastStakedTime, the admin
        //can stop including further stakes.
    }

    // modifier onlyOwner{
    //     require(msg.sender == admin, "you are not admin.");
    //     _;
    // }

    struct portfolio {
        uint amount;
        bool registered;
        bool staked;
        uint maturityTime;
    }

    //not the efficient way of doing things.
    // address[] internal stakeholders;
    mapping(address => portfolio) redBook;

    event staked(address, uint);
    address public highestStaker;
    uint public highestStake = 0;
    function isStakeholder(address _address) public view returns(bool) {
        if(redBook[_address].registered){
            return true;
        }
        return false;
    }

    function addStakeholder(address _address) public onlyOwner {
        redBook[_address].registered = true;
        //should I add msg.value to this function after making it payable or different function works?
    }

    function removeStakeholder(address _address) public {
        require(msg.sender == admin || msg.sender == _address, "You are neither owner, nor the admin.");
        uint payBack = redBook[_address].amount;
        // require(redBook[_address].staked, "You don't have money staked");
        if(block.timestamp > redBook[_address].maturityTime){
            if(payBack>0){
                IERC20(contractAddress).transfer(_address, payBack);
                IERC20(rewardContractAddress).transfer(_address, payBack*(104)/(100));
                if(_address == highestStaker){
                    IERC20(rewardContractAddress).transfer(_address, 5);
                    //giving the highest staker only limited money so that they won't misuse the system too much?
                }
            }
            //modify the reward function later, such that it gives reward according to how much time the user
            //is waiting to redeem his/her tokens.
        }
        else{
            if(payBack>0){
                IERC20(contractAddress).transfer(_address, payBack*(90)/(100));
            }
        }
        redBook[_address].amount = 0;
        redBook[_address].registered = false;
        redBook[_address].staked = false;
        redBook[_address].maturityTime = 0;
    }

    function onStaking() public onlyOwner {
        canStake = true;
    }

    function OffStaking() public onlyOwner {
        require(block.timestamp > lastStakedTime + 300, "Can't turn off staking right now.");
        canStake = false;
    }

    function stake(uint _amount) public  {
        require(isStakeholder(msg.sender), "You are not a registered stakeholder.");
        require(canStake, "Owner has closed the staking option for now.");
        require(_amount <= contractAddress.balanceOf(msg.sender), "Balance too low");
        require(redBook[msg.sender].amount == 0, "You have already staked your tokens.");
        //use this upper require until I implement new better structure for staking multiple amounts with corresponding timestamps.
        redBook[msg.sender].amount = _amount;
        lastStakedTime = block.timestamp;
        contractAddress.transferFrom(msg.sender, address(this), _amount);
        redBook[msg.sender].staked = true;
        redBook[msg.sender].maturityTime = 100 + block.timestamp;
        emit staked(msg.sender,  _amount);
        if(_amount>highestStake){
            highestStake = _amount;
            highestStaker = msg.sender;
        }
    }

    function unStake() public {
        require(isStakeholder(msg.sender), "You are not a registered stakeholder.");
        require(redBook[msg.sender].staked, "You haven't staked any tokens.");
        uint payBack = redBook[msg.sender].amount;
        //using interval system to reward the users, so if they have waited for 3 extra blocks of 10 seconds, they will get 3 more tokens?
        if(block.timestamp > redBook[msg.sender].maturityTime){
            IERC20(rewardContractAddress).transfer(msg.sender, payBack*(5)/(100));
            IERC20(contractAddress).transfer(msg.sender, payBack);
            console.log("1");
            if(msg.sender == highestStaker){
                IERC20(rewardContractAddress).transfer(msg.sender, payBack*(1)/(100));
                console.log("1");
                //giving extra 1% to the highest staker.
                //but what will happen once the highest staker cashes out?
                //How will we reset the variables?
                highestStake = 0;
            }
        }
        else{
            IERC20(contractAddress).transfer(msg.sender, payBack*(90)/(100));
            console.log("1");
        }
        redBook[msg.sender].amount = 0;
        console.log("1");
        redBook[msg.sender].staked = false;
        console.log("1");
    }
}