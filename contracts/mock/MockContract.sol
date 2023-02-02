/*
 SPDX-License-Identifier: MIT
*/

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/**
 * @author Publius
 * @title Mock Contract with a getter,setter, ERC20 deposit/withdraw functionality
**/
contract MockContract {

    using SafeERC20 for IERC20;
    address account;
    mapping (address => mapping(IERC20 => uint256)) tokenData;

    function setAccount(address _account) external {
        account = _account;
    }

    function getAccount() external view returns (address _account) {
        _account = account;
    }

    function deposit(IERC20 token, uint256 amt) external { 
        token.safeTransferFrom(msg.sender,address(this),amt);
        tokenData[msg.sender][token] += amt;
    }

    function withdraw(IERC20 token, uint256 amt) external {
        tokenData[msg.sender][token] -= amt;
        token.safeTransferFrom(address(this),msg.sender,amt);
    }

}
