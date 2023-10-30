// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Exchange {
    address public owner;
    address public erc20TokenAddress;
    uint256 public totalLiquidityPositions;
    //constant of k gets updated based on 
    uint256 public constant k;

    //local storage of the amount of liquidty a user has
    mapping(address => uint256) public liquidityPositions;
    
    //set up events to emit in the functions
    event LiquidityProvided(address indexed provider, uint amountERC20Token, uint amountEth, uint liquidityPositionsIssued);
    event LiquidityWithdrawn(address indexed provider, uint amountERC20Token, uint amountEth, uint liquidityPositionsBurned);

    constructor(address _erc20TokenAddress) {
        owner = msg.sender;
        erc20TokenAddress = _erc20TokenAddress;
    }

    function provideLiquidity(uint _amountERC20Token) external returns (uint) {

        //connect to the Token interface based on the address
        IERC20 erc20Token = IERC20(erc20TokenAddress);

        //get the eth balence of the contract
        uint256 ethBalance = address(this).balance;
        //get the token balence of this contract from the token interface
        uint256 erc20Balance = erc20Token.balanceOf(address(this));
        uint256 liquidityPositionsIssued;
        
        //Check to make sure the user deposits the proper ratio 
        require((totalLiquidityPositions * _amountERC20Token)/erc20Balance == (totalLiquidityPositions * msg.value)/ethBalance, "Not the proper ratio sent");

        //if first liquity provieder, give 100 postions
        if (liquidityPositions[msg.sender] == 0) {
            liquidityPositionsIssued = 100;
        } else {
            //Get the proper amount of liquity positions based on how much you enter
            liquidityPositionsIssued = (totalLiquidityPositions * _amountERC20Token) / erc20Balance;
        }

        //update total
        totalLiquidityPositions += liquidityPositionsIssued;
        //update the amount of liquity positions of the contract interacter
        liquidityPositions[msg.sender] += liquidityPositionsIssued;
        
        //get the tokens from the sender
        erc20Token.transferFrom(msg.sender, address(this), _amountERC20Token);
        //get the eth from sender
        payable(address(this)).transfer(msg.value);
        payable(msg.sender).transfer((ethBalance * _amountERC20Token) / erc20Balance);
        

        //update new K ratio after new deposit
        k = address(this).balance / erc20Token.balanceOf(address(this));
        
        //emit the liquidity event
        emit LiquidityProvided(msg.sender, _amountERC20Token, (ethBalance * _amountERC20Token) / erc20Balance, liquidityPositionsIssued);
        
        //return the amount of liquity positions issued to the user
        return liquidityPositionsIssued;
    }

    //Return the current amount of liqudity positions of the user
    function getMyLiquidityPositions() external view returns (uint) {
        return liquidityPositions[msg.sender];
    }


    function withdrawLiquidity(uint _liquidityPositionsToBurn) external returns (uint, uint) {
        //Make sure the user has enough liquidity positions to liquidate
        require(liquidityPositions[msg.sender] >= _liquidityPositionsToBurn, "Insufficient liquidity positions");

        //connect to the token interface
        IERC20 erc20Token = IERC20(erc20TokenAddress);

        //get the contracts eth balance
        uint256 ethBalanceBefore = address(this).balance;
        //get the contracts token balance
        uint256 erc20BalanceBefore = erc20Token.balanceOf(address(this));

        //calculate the amount of eth and tokens to send
        uint256 amountEthToSend = (ethBalanceBefore * _liquidityPositionsToBurn) / totalLiquidityPositions;
        uint256 amountERC20ToSend = (erc20BalanceBefore * _liquidityPositionsToBurn) / totalLiquidityPositions;

        //remove the liquidity positions out of the users bucket
        liquidityPositions[msg.sender] -= _liquidityPositionsToBurn;
        //remove the liquidity positions out of the total pot
        totalLiquidityPositions -= _liquidityPositionsToBurn;

        //transfer eth to the user
        payable(msg.sender).transfer(amountEthToSend);
        //transfer tokens to the sender
        erc20Token.transfer(msg.sender, amountERC20ToSend);

        //emit the withdraw event
        emit LiquidityWithdrawn(msg.sender, amountERC20ToSend, amountEthToSend, _liquidityPositionsToBurn);
        //return the amount of eth and token sent to the user
        return (amountERC20ToSend, amountEthToSend);
    }
}