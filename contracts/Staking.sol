pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Token.sol";


contract Token is MyToken {
    address public admin;
    IERC20 public contractAddress;
    constructor(uint initialSupply, address _contractAddress) public{
        admin = msg.sender;
        _mint(msg.sender, initialSupply);
        contractAddress = IERC20(_contractAddress);
    }

    modifier onlyowner{
        require(msg.sender == admin, "you are not admin.");
        _;
    }

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

    function isStakeholder(address _address) public view returns(bool) {
        if(redBook[_address].registered){
            return true;
        }
        return false;
    }

    function addStakeholder(address _address) public onlyowner {
        redBook[_address].registered = true;
        //should I add msg.value to this function after making it payable or different function works?
    }

    function removeStakeholder(address _address) public {
        require(msg.sender == admin || msg.sender == _address, "You are neither owner, nor the admin.");
        uint payBack = redBook[_address].amount;
        // require(redBook[_address].staked, "You don't have money staked");
        if(block.timestamp > redBook[_address].maturityTime){
            if(payBack>0){
                IERC20(contractAddress).transfer(_address, payBack+10);
            }
            //modify the reward function later, such that it gives reward according to how much time the user
            //is waiting to redeem his/her tokens.
        }
        else{
            if(payBack>0){
                IERC20(contractAddress).transfer(_address, payBack*(95)/(100));
            }
        }
        redBook[_address].amount = 0;
        redBook[_address].registered = false;
        redBook[_address].staked = false;
        redBook[_address].maturityTime = 0;
    }

    function stake(uint _amount) public  {
        require(isStakeholder(msg.sender), "You are not a registered stakeholder.");
        require(_amount <= contractAddress.balanceOf(msg.sender), "Balance too low");
        require(redBook[msg.sender].amount == 0, "You have already staked your tokens.");
        //use this upper require until I implement new better structure for staking multiple amounts with corresponding timestamps.
        redBook[msg.sender].amount = _amount;
        contractAddress.transferFrom(msg.sender, address(this), _amount);
        redBook[msg.sender].staked = true;
        redBook[msg.sender].maturityTime = 100 + block.timestamp;
         emit staked(msg.sender,  _amount);
    }

    function unStake() public {
        require(isStakeholder(msg.sender), "You are not a registered stakeholder.");
        require(redBook[msg.sender].staked, "You haven't staked any tokens.");
        uint payBack = redBook[msg.sender].amount;
        //using interval system to reward the users, so if they have waited for 3 extra blocks of 10 seconds, they will get 3 more tokens?
        if(block.timestamp > redBook[msg.sender].maturityTime){
            IERC20(contractAddress).transfer(msg.sender, payBack*(105)/(100));
        }
        else{
            IERC20(contractAddress).transfer(msg.sender, payBack*(90)/(100));
        }
        redBook[msg.sender].amount = 0;
        redBook[msg.sender].staked = false;
    }
}