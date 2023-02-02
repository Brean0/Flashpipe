// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {IBeanstalk, To, From} from "./interfaces/IBeanstalk.sol";
import {DepotFacet} from "./facets/DepotFacet.sol";
import {TokenSupportFacet} from "./facets/TokenSupportFacet.sol";
import {LibFunction} from "./libraries/LibFunction.sol";
import {LibFlashLoan} from "./libraries/LibFlashLoan.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/drafts/IERC20Permit.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC4494} from "./interfaces/IERC4494.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanRecipient} from "./interfaces/IFlashLoanRecipient.sol";
import {IVault} from "./interfaces/IVault.sol";



/**
 * @title FlashDepot
 * @author Publius, Brean
 * @notice Depot wraps Pipeline's Pipe functions to facilitate the loading of non-Ether assets in Pipeline
 * in the same transaction that loads Ether, Pipes calls to other protocols and unloads Pipeline.
 * @notice flashDepot is a fork of Depot that allows users to ultilize flash loans.
 * https://evmpipeline.org
**/

contract Depot is IFlashLoanRecipient, DepotFacet, TokenSupportFacet {

    using SafeERC20 for IERC20;
    
    IBeanstalk private constant beanstalk =
        IBeanstalk(0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5);
    address private constant vault = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    /**
     * 
     * Farm
     * 
    **/

    /**
     * @notice Execute multiple function calls in Depot.
     * @param data list of encoded function calls to be executed
     * @return results list of return data from each function call
     * @dev Implementation from https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol.
    **/
    function farm(bytes[] calldata data)
        external
        payable
        returns (bytes[] memory results)
    {
        return _farm(data);
    }
    
    function _farm(bytes[] calldata data)
        internal
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            LibFunction.checkReturn(success, result);
            results[i] = result;
        }
    }

    /**
     *
     * Transfer
     *
    **/

    /**
     * @notice Execute a Beanstalk ERC-20 token transfer.
     * @dev See {TokenFacet-transferToken}.
     * @dev Only supports INTERNAL and EXTERNAL From modes.
    **/
    function transferToken(
        IERC20 token,
        address recipient,
        uint256 amount,
        From fromMode,
        To toMode
    ) external payable {
        if (fromMode == From.EXTERNAL) {
            token.transferFrom(msg.sender, recipient, amount);
        } else if (fromMode == From.INTERNAL) {
            beanstalk.transferInternalTokenFrom(token, msg.sender, recipient, amount, toMode);
        } else {
            revert("Mode not supported");
        }
    }

    /**
     * @notice Execute a single Beanstalk Deposit transfer.
     * @dev See {SiloFacet-transferDeposit}.
    **/
    function transferDeposit(
        address sender,
        address recipient,
        address token,
        uint32 season,
        uint256 amount
    ) external payable returns (uint256 bdv) {
        require(sender == msg.sender, "invalid sender");
        bdv = beanstalk.transferDeposit(msg.sender, recipient, token, season, amount);
    }

    /**
     * @notice Execute multiple Beanstalk Deposit transfers of a single Whitelisted Tokens.
     * @dev See {SiloFacet-transferDeposits}.
    **/
    function transferDeposits(
        address sender,
        address recipient,
        address token,
        uint32[] calldata seasons,
        uint256[] calldata amounts
    ) external payable returns (uint256[] memory bdvs) {
        require(sender == msg.sender, "invalid sender");
        bdvs = beanstalk.transferDeposits(msg.sender, recipient, token, seasons, amounts);
    }

    /**
     *
     * Permits
     *
    **/

    /**
     * @notice Execute a permit for an ERC-20 Token stored in a Beanstalk Farm balance.
     * @dev See {TokenFacet-permitToken}.
    **/
    function permitToken(
        address owner,
        address spender,
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        beanstalk.permitToken(owner, spender, token, value, deadline, v, r, s);
    }

    /**
     * @notice Execute a permit for Beanstalk Deposits of a single Whitelisted Token.
     * @dev See {SiloFacet-permitDeposit}.
    **/
    function permitDeposit(
        address owner,
        address spender,
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        beanstalk.permitDeposit(owner, spender, token, value, deadline, v, r, s);
    }

    /**
     * @notice Execute a permit for a Beanstalk Deposits of a multiple Whitelisted Tokens.
     * @dev See {SiloFacet-permitDeposits}.
    **/
    function permitDeposits(
        address owner,
        address spender,
        address[] calldata tokens,
        uint256[] calldata values,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        beanstalk.permitDeposits(owner, spender, tokens, values, deadline, v, r, s);
    }



    
    // flash pipe embeds a flash loan call to balancer.
    // flash pipe calls {farm}, and converts data into bytes
    // to be compatable with pipeline. 
    function flashPipe(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory data
    ) external {
        IVault(vault).flashLoan(IFlashLoanRecipient(this), tokens, amounts, data);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory,
        bytes memory userData
    ) external override {
        require(msg.sender == vault);
        // call farm with data
        this.farm(this.convertBytesToArray(userData));
        // transfer tokens back
        for(uint i; i < tokens.length; ++i ){
            tokens[i].transfer(vault, amounts[i]);
        }
    }

    // FIXME: needs rigorus testing
    // may also be much easier via calldata
    /// @dev used to convert farm bytes[] array into a single bytes, formmatted as such:
    // [1 bytes     |1 bytes           | X bytes  | 1 bytes         | X bytes           ]
    // [data.length | data[0].length   | data[0]  | bytes[n].length | farmDataBytes[n]  ]
    // should be used externally to prepare data
    function convertByteArrayToBytes(bytes[] memory data) public pure returns (bytes memory) {
        uint256 totalLength = 1;
        for(uint i; i < data.length; ++i){
            totalLength += data[i].length + 1;
        }
        bytes memory _data = new bytes(totalLength);
        _data = LibFunction.paste32Bytes(abi.encodePacked(data.length),_data,63,32);
        uint256 prevLength = 1;
        for(uint i; i < data.length; ++i){
            if(data[i].length <= 31){
                _data = LibFunction.paste32Bytes(data[i],_data,31,32 + prevLength);
                prevLength = prevLength + data[i].length + 1;
            } else {
                uint256 loops = ((data[i].length) / 32) + 1;
                uint256 mod = (data[i].length + 1) % 32;
                _data = LibFunction.paste32Bytes(data[i],_data,31,32 + prevLength);
                prevLength = prevLength + 32;
                uint j = 1;
                for(j ;j < loops - 1 ; ++j){
                    _data = LibFunction.paste32Bytes(data[i],_data,31 + 32*j,32 + prevLength);
                    prevLength = prevLength + 32;
                }
                _data = LibFunction.paste32Bytes(data[i],_data,31 + 32*j,32 + prevLength);
                prevLength = prevLength + mod;
            }
        }
         return _data;
    }

    // converts a bytes into a bytes memory, based on the format from `convertByteArrayToBytes`
    function convertBytesToArray(bytes calldata data) external pure returns(bytes[] memory) {
        // get first byte 
        bytes1 length = data[0];
        // use that to determine length of data
        bytes[] memory returnData = new bytes[](uint8(length));

        // get next byte representing length of data: 
        bytes1 dataLength;
        uint256 startIndex = 1;
        // uint256 endIndex;
        for(uint i; i < returnData.length; i++){
            startIndex = startIndex + uint8(dataLength) + 1;
            dataLength = data[startIndex - 1];
            returnData[i] = data[startIndex : startIndex + uint8(dataLength)];  
        }
        return returnData;
    }
}
