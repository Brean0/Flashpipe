/*
 SPDX-License-Identifier: MIT
*/

pragma solidity >=0.7.6 <0.9.0;

pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPipeline.sol";
import "./LibFunction.sol";


/**
 * @title LibFlashLoan
 * @author Brean
 **/

library LibFlashLoan {

    enum Type {
        basic,
        singlePaste,
        MultiPaste
    }
    
    // transfer flashed tokens
    function transferTokens(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        address to
    ) external returns (bool success) {
        for(uint i; i < tokens.length; i++){
            tokens[i].transfer(to, amounts[i]);
        }
        return true;
    }

    // FIXME: needs rigorus testing
    // can we do this with bytes[] calldata? 
    /// @dev used to convert farm bytes[] array into a single bytes, formmatted as such:
    // [1 bytes     |2 bytes           | X bytes  | 2 bytes         | X bytes           ]
    // [data.length | data[0].length   | data[0]  | bytes[n].length | farmDataBytes[n]  ]
    // should be used externally to prepare data
    function convertByteArrayToBytes(bytes[] memory data) external pure returns (bytes memory) {
        
        uint256 totalLength = 1;
        for(uint i; i < data.length; ++i){
            totalLength += data[i].length + 2;
        } 
        bytes memory _data = new bytes(totalLength);
        _data = LibFunction.paste32Bytes(abi.encodePacked(data.length),_data,63,32);
        uint256 prevLength = 1;
        for(uint i; i < data.length; ++i){
            if(data[i].length <= 30){
                _data = LibFunction.paste32Bytes(data[i],_data,30,32 + prevLength);
                prevLength = prevLength + data[i].length + 1;
            } else {
                uint256 loops = (((data[i].length) + 1)/ 32) + 1;
                uint256 mod = (data[i].length + 2) % 32;
                uint j;
                for(j ;j < loops - 1 ; ++j){
                    _data = LibFunction.paste32Bytes(data[i],_data,30 + 32*j,32 + prevLength);
                    prevLength = prevLength + 32;
                }
                _data = LibFunction.paste32Bytes(data[i],_data,30 + 32*j,32 + prevLength);
                prevLength = prevLength + mod;
            }
        }
         return _data;
    }


    // converts a bytes into a bytes memory, based on the format from `convertByteArrayToBytes`
    function convertBytesToArray(bytes calldata data) external pure returns(bytes[] memory) {
        
        bytes1 length = data[0];
        bytes[] memory returnData = new bytes[](uint8(length)); 
        bytes memory dataLength;
        uint256 lengthOfData;
        uint256 startIndex = 2;

        for(uint i; i < returnData.length; i++){
            startIndex = startIndex + lengthOfData + 1; //
            dataLength = data[startIndex - 2 : startIndex];  
            assembly {
                lengthOfData := shr(240,mload(add(dataLength, 0x20)))
            }
            returnData[i] = data[startIndex : startIndex + uint16(lengthOfData)];  
            
        }
        return returnData;
    }

    // clipboardHelper helps create the clipboard data for an AdvancePipeCall
    /// 
    /// @param useEther Whether or not the call uses ether
    /// @param amount amount of ether to send
    /// @param _type What type the advanceCall is.
    /// @param returnDataIndex which previous advancedPipeCall 
    // to copy from, ordered by execution.
    /// @param copyIndex what index to copy the data from.
    // this will copy 32 bytes from the index.
    /// @param pasteIndex what index to paste the copyData
    // into calldata
    function clipboardHelper (
        bool useEther,
        uint256 amount,
        Type _type,
        uint256 returnDataIndex,
        uint256 copyIndex,
        uint256 pasteIndex
    ) external pure returns (bytes memory) {
        uint256 clipboardData;
        clipboardData = clipboardData | uint256(_type) << 248;
        clipboardData = clipboardData 
            | returnDataIndex << 160
            | (copyIndex * 32) + 32 << 80
            | (pasteIndex * 32) + 36;
        if (useEther) {
            clipboardData = clipboardData | 1 << 240;
            return abi.encodePacked(clipboardData, amount);
        } else {
            return abi.encodePacked(clipboardData);
        }
    }

    // TODO: test
    // advancedClipboardHelper helps create the clipboard data for an AdvancePipeCall
    // that takes n paste params.
    function advancedClipboardHelper(
        bool useEther,
        uint256 amount,
        Type _type,
        uint256[] calldata returnDataIndex,
        uint256[] calldata copyIndex,
        uint256[] calldata pasteIndex
    ) external pure returns (bytes memory clipboard) {
        uint256[] memory clipboardData;
        clipboardData[0] = clipboardData[0] | uint256(_type) << 248;
        if (useEther) {
            clipboardData[0] = clipboardData[0] | 1 << 240;
        }
        for(uint i = 2; i < returnDataIndex.length; ++i){
            clipboardData[i] = clipboardData[i] 
            | returnDataIndex[i-2] << 160
            | (copyIndex[i-2] * 32) + 32 << 80
            | (pasteIndex[i-2] * 32) + 36;
        }
        clipboard = abi.encodePacked(clipboardData[0]);
        for(uint i = 1; i < clipboardData.length; i++){
            clipboard = abi.encodePacked(clipboard,clipboardData[i]);
        }
        clipboard = abi.encodePacked(clipboard,amount);
    }

}
