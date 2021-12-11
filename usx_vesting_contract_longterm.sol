// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts@4.4.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.4.0/utils/math/SafeMath.sol";
import "@openzeppelin/contracts@4.4.0/access/Ownable.sol";

//Vesting for (LongTerm Holder)
contract USX_Vesting is Ownable{
    using SafeMath for uint256;
    IERC20 token;
    //uint vestingLock = 12; //months
    uint vestingLockDays = 30; //
    uint256 daytimestamp = 86400; //Live
    uint256 vestBalance;
    uint8 deployed = 0;
    uint256 totalVesting = 0;
    uint totalAddresses = 0;
    uint256 totalClaimed = 0;

    struct vestingBox {
        uint256 totalBalance;
        uint256 remainingBalance;
        uint256 monthsLock;
        uint lastRelease;
        uint8 counter;
        uint8 temporaryCounter;
        uint8 flag;
    }

    address[] vestaddr; //List of addresses
    uint256[] vestamount; //List of amounts
    uint[] vestlockMonths; //List of Months lock

    //address[] vestaddr = [0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,0x66c77825cA44CfAcD427a1dA304046CE7446bd0D,0xF4Ec2db1F22067979D0A9c3babfFE5B5A7Cecc15,0xc9044AD8BC368c3C10357f21445e6C0b50bac40D];
    //uint256[] vestamount = [1350000000000,638462341890,84074000000,1526257000000];
    //uint256[] vestlockMonths = [12,12,12,12];

    mapping(address => vestingBox) private vestingBoxes;

    constructor(address tokenContract) {
        token = IERC20(tokenContract);
        distributeTokens();
    }

    function addAddressVesting(address addr, uint256 amount, uint256 months) public onlyOwner{
        require(amount <= token.balanceOf(msg.sender), "you don't have enough balance.");
        IERC20(token).transferFrom(msg.sender ,address(this), amount);  
        addVB(addr, amount, amount, block.timestamp, months);
    }

    function _fixAmount(uint256 amount) private pure returns (uint256){
        return amount * 10 ** 12;
    }

    function contractTokenBalance() public view returns (uint256){
        return IERC20(token).balanceOf(address(this));
    }

    function myBalance() public view returns (uint256){
        return IERC20(token).balanceOf(address(msg.sender));
    }

    function showRemainingBalance() public view returns (uint256){
        if(vestingBoxes[msg.sender].flag==1){
            return vestingBoxes[msg.sender].remainingBalance;
        }
        return 0;
    }

    function showTotalBalance() public view returns (uint256){
        if(vestingBoxes[msg.sender].flag==1){
            return vestingBoxes[msg.sender].totalBalance;
        }
        return 0;
    }

    function nextReleaseToken() public view returns(uint256){
        if(vestingBoxes[msg.sender].counter<=vestingBoxes[msg.sender].monthsLock && vestingBoxes[msg.sender].flag==1){
            return (block.timestamp-vestingBoxes[msg.sender].lastRelease) * 100000;
        }else{
            return 0;
        }
    }

    function myVestingInfo() public view returns (uint256 _myTotalVesting, uint256 _myRemainingBalance, uint256 _claimable, uint8 _counter, uint256 _monthsLock,  uint256 _nextReleaseToken){
        uint256 myTotalVesting = showTotalBalance();
        uint256 myRemainingBalance = showRemainingBalance();
        (uint256 claimable,uint8 temporaryCounter) = showClaimable();
        return (myTotalVesting,myRemainingBalance,claimable,temporaryCounter,vestingBoxes[msg.sender].monthsLock,vestingBoxes[msg.sender].lastRelease);
    }

    function vestingInfo() public view returns (uint256 _totalVesting,uint _totalAddresses,uint256 _totalSupply,uint256 _totalClaimed,uint256 _contractSupply){
        uint256 totalSupply = IERC20(token).totalSupply();
        uint256 contractSupply = IERC20(token).balanceOf(address(this));
        return (totalVesting,totalAddresses,totalSupply,totalClaimed,contractSupply);
    }

    function showClaimable() public view returns(uint256 amount, uint8 counter){
        //require(vestingBoxes[msg.sender].flag==1,"Address not in vesting schedule.");
        if(vestingBoxes[msg.sender].flag==1){
            //require(vestingBoxes[msg.sender].counter<=vestingLock,"Address already claimed vesting.");
            if(vestingBoxes[msg.sender].counter<=vestingBoxes[msg.sender].monthsLock){
                uint8 temporaryCounter = 0;
                uint256 totalAmount = vestingBoxes[msg.sender].totalBalance;
                uint256 tokenPerMonth;
                uint256 claimedToken = totalAmount - vestingBoxes[msg.sender].remainingBalance;
                uint256 claimable;
                //live code
                uint256 beneficiaryTime = (block.timestamp-vestingBoxes[msg.sender].lastRelease) * 100;
                uint256 claimtimes = (beneficiaryTime / (daytimestamp * vestingLockDays));
                
                //uint256 beneficiaryTime = (block.timestamp-vestingBoxes[msg.sender].lastRelease) * 100000;
                //uint256 claimtimes = (beneficiaryTime / (daytimestamp * vestingLockDays));
                if(claimtimes>=100){
                    do {
                        if(claimedToken<=totalAmount && claimable<=totalAmount){
                            temporaryCounter += 1;
                            if((temporaryCounter+vestingBoxes[msg.sender].counter)<=vestingBoxes[msg.sender].monthsLock){
                                if((temporaryCounter+vestingBoxes[msg.sender].counter)<=2){
                                    tokenPerMonth = totalAmount.mul(3125).div(100000);
                                }else if((temporaryCounter+vestingBoxes[msg.sender].counter)>=3 && (temporaryCounter+vestingBoxes[msg.sender].counter)<=4){
                                    tokenPerMonth = totalAmount.mul(4000).div(100000);
                                }else if((temporaryCounter+vestingBoxes[msg.sender].counter)>=5){
                                    tokenPerMonth = totalAmount.mul(6125).div(100000);
                                }
                               claimable = claimable.add(tokenPerMonth);
                            }
                            claimtimes -= 100;
                        }else{
                            break;
                        }
                    } while(claimtimes>=100);
                    return (claimable,temporaryCounter);
                }
            }
        }
    }

    function tokenLastRelease() public view returns(uint){
        if(vestingBoxes[msg.sender].flag==1){
            return vestingBoxes[msg.sender].lastRelease;
        }
        return 0;
    }

    function claimVesting() public payable returns(uint256){
        (uint256 claimable,uint8 temporaryCounter) = showClaimable();
        if(claimable>0){
            //check if balance is has greater than the claimable;
            require(IERC20(token).balanceOf(address(this))>=claimable,"Contract don't have enough balance to cover the transaction.");
            IERC20(token).transfer(msg.sender,claimable);
            vestingBoxes[msg.sender].lastRelease = block.timestamp;
            vestingBoxes[msg.sender].counter += temporaryCounter;
            vestingBoxes[msg.sender].remainingBalance -= claimable;
            totalClaimed += claimable;
            return claimable;
        }
        return 0;
    }

    function distributeTokens() public payable onlyOwner{
        require(deployed==0,"Vesting to address has already been deployed.");
        for(uint i=0; i<=vestaddr.length-1; i++){
            uint256 amount = _fixAmount(vestamount[i]);
            uint256 vestingLock = vestlockMonths[i];
            addVB(vestaddr[i], amount, amount, block.timestamp, vestingLock);
        }
        deployed = 1;
    }

    function addVB(address addr, uint256 amount, uint256 _rBalance, uint lastRelease, uint256 vestingLock) private{
        vestingBox storage vbox = vestingBoxes[addr];
        vbox.totalBalance = amount;
        vbox.remainingBalance = _rBalance;
        vbox.monthsLock = vestingLock;
        vbox.lastRelease = lastRelease;
        vbox.counter = 0;
        vbox.temporaryCounter = 0;
        vbox.flag = 1;
        totalVesting += amount;
        totalAddresses++;
    }
    

}
