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

    //function to estimate the eth to provide based on the token amount
    function estimateEthToProvide(uint _amountERC20Token) external view returns (uint) {
        
        //connect to the token interface with the address from above
        IERC20 erc20Token = IERC20(erc20TokenAddress);

        //get the eth balence of the contract
        uint256 contractEthBalance = address(this).balance;

        //get the token balence of this contract from the token interface
        uint256 contractERC20TokenBalance = erc20Token.balanceOf(address(this));

        //return the amount of eth to send
        return (contractEthBalance * _amountERC20Token) / contractERC20TokenBalance;
    }

    //function to estimate the token to provide based on the eth amount
    //users will use this to find out how much ERC-20 token to deposit if they want to deposit an amount of ETh
    function estimateERC20TokenToProvide(uint _amountEth) external view returns (uint) {
        
        //connect to the token interface with the address from above
        IERC20 erc20Token = IERC20(erc20TokenAddress);

        //get the eth balence of the contract
        uint256 contractEthBalance = address(this).balance;

        //get the token balence of this contract from the token interface
        uint256 contractERC20TokenBalance = erc20Token.balanceOf(address(this));

        //return the amount of eth to send
        return (contractERC20TokenBalance * _amountEth) / contractEthBalance;
    }


    //fucntion to estimate the amount of eth to give the caller based on the amount of ERC20 token caller wishes to swap for when a user wants to know how much ether to expect when calling swapForEth
    function estimateSwapForEth(uint _amountERC20Token) external view returns (uint) {
        //connect to the token interface with the address from above
        IERC20 erc20Token = IERC20(erc20TokenAddress);

        //get the eth balence of the contract
        uint256 contractEthBalance = address(this).balance;

        //get the token balence of this contract from the token interface
        uint256 contractERC20TokenBalance = erc20Token.balanceOf(address(this));

        //get the contract token balance after the swap
        uint256 contractERC20TokenBalanceAfterSwap = contractERC20TokenBalance + _amountERC20Token;

        //get the contract eth balance after the swap
        uint256 contractEthBalanceAfterSwap = k / contractERC20TokenBalanceAfterSwap;

        //return the amount of eth to send
        return contractEthBalance - contractEthBalanceAfterSwap;
       
    }

    //fucntion to return amount of eth sent when caller deposits some ERC20 token in return for eth
    function swapForEth(uint _amountERC20Token) external returns (uint) {
        //connect to the token interface with the address from above
        IERC20 erc20Token = IERC20(erc20TokenAddress);

        //get the eth balence of the contract
        uint256 contractEthBalance = address(this).balance;

        //get the token balence of this contract from the token interface
        uint256 contractERC20TokenBalance = erc20Token.balanceOf(address(this));

        //get the contract token balance after the swap
        uint256 contractERC20TokenBalanceAfterSwap = contractERC20TokenBalance + _amountERC20Token;

        //get the contract eth balance after the swap
        uint256 contractEthBalanceAfterSwap = k / contractERC20TokenBalanceAfterSwap;

        //get the amount of eth to send to the caller
        uint256 amountEthToSend = contractEthBalance - contractEthBalanceAfterSwap;

        //transfer the tokens from the caller to the contract
        erc20Token.transferFrom(msg.sender, address(this), _amountERC20Token);

        //transfer the eth to the caller
        payable(msg.sender).transfer(amountEthToSend);

        //return the amount of eth sent to the caller
        return amountEthToSend;
    }

    //function for when caller wants to know how much ERC20 token to expect when calling swapForERC20Token
    function estimateSwapForERC20Token(uint _amountEth) external view returns (uint) {
        //connect to the token interface with the address from above
        IERC20 erc20Token = IERC20(erc20TokenAddress);

        //get the eth balence of the contract
        uint256 contractEthBalance = address(this).balance;

        //get the token balence of this contract from the token interface
        uint256 contractERC20TokenBalance = erc20Token.balanceOf(address(this));

        //get the contract eth balance after the swap
        uint256 contractEthBalanceAfterSwap = contractEthBalance + _amountEth;

        //get the contract token balance after the swap
        uint256 contractERC20TokenBalanceAfterSwap = k / contractEthBalanceAfterSwap;

        //return the amount of eth to send
        return contractERC20TokenBalance - contractERC20TokenBalanceAfterSwap;
    }

    //function to return amount of ERC20 token sent when caller deposits some ETH in return for ERC20 token
    function swapForERC20Token(uint _amountEth) external returns (uint) {
        //connect to the token interface with the address from above
        IERC20 erc20Token = IERC20(erc20TokenAddress);

        //get the eth balence of the contract
        uint256 contractEthBalance = address(this).balance;

        //get the token balence of this contract from the token interface
        uint256 contractERC20TokenBalance = erc20Token.balanceOf(address(this));

        //get the contract eth balance after the swap
        uint256 contractEthBalanceAfterSwap = contractEthBalance + _amountEth;

        //get the contract token balance after the swap
        uint256 contractERC20TokenBalanceAfterSwap = k / contractEthBalanceAfterSwap;

        //get the amount of ERC20 token to send to the caller
        uint256 amountERC20TokenToSend = contractERC20TokenBalance - contractERC20TokenBalanceAfterSwap;

        //transfer the eth from the caller to the contract
        payable(address(this)).transfer(_amountEth);

        //transfer the ERC20 token to the caller
        erc20Token.transfer(msg.sender, amountERC20TokenToSend);

        //return the amount of ERC20 token sent to the caller
        return amountERC20TokenToSend;
    }







}