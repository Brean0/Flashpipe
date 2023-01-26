/*
 SPDX-License-Identifier: MIT
*/

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LibFlashLoan
 * @author Brean
 **/

library LibFlashLoan {
    function TransferFlashedTokens(
        IERC20[] memory tokens
    ) internal returns (bool success) {
        for(uint i; i < tokens.length; i++){
            tokens[i].transfer(address(0xBA12222222228d8Ba445958a75a0704d566BF2C8), tokens[i].balanceOf(address(this)));
        }
        return true;
    }
}
