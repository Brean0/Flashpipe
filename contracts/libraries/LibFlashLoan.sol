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

    enum clipBoardType {
        basic,
        singlePaste,
        MultiPaste
    }
    
    // transfer flashed tokens
    function TransferFlashedTokens(
        IERC20[] memory tokens,
        uint256[] memory amounts
    ) internal returns (bool success) {
        for(uint i; i < tokens.length; i++){
            tokens[i].transfer(address(0xBA12222222228d8Ba445958a75a0704d566BF2C8), amounts[i]);
        }
        return true;
    }

    // FIXME: needs rigorus testing
    // can we do this with bytes[] calldata? 
    /// @dev used to convert farm bytes[] array into a single bytes, formmatted as such:
    // [1 bytes     |2 bytes           | X bytes  | 2 bytes         | X bytes           ]
    // [data.length | data[0].length   | data[0]  | bytes[n].length | farmDataBytes[n]  ]
    // should be used externally to prepare data
    /// @notice CORRECT
    function convertByteArrayToBytes(bytes[] memory data) external pure returns (bytes memory) {
        uint256 totalLength = 1;
        // for every index, we add the length of the array and 2, to account for the length
        for(uint i; i < data.length; ++i){
            totalLength += data[i].length + 2;
        }
        
        bytes memory _data = new bytes(totalLength);
        _data = LibFunction.paste32Bytes(abi.encodePacked(data.length),_data,63,32);
        // console.log("lengthBytes:");
        // console.logBytes(_data);
        uint256 prevLength = 1;
        for(uint i; i < data.length; ++i){
            // if the length is greater than 30, we need to loop as we can only paste 32 bytes at a time
            if(data[i].length <= 30){
                _data = LibFunction.paste32Bytes(data[i],_data,30,32 + prevLength);
                prevLength = prevLength + data[i].length + 1;
            } else {
                // 34 byte number -> 2 loops, 1 32 + 4 
                // 33 byte number -> 2 loops
                // 31 byte -> 2 loops
                // 30 byte number -> 1 loops
                uint256 loops = (((data[i].length) + 1)/ 32) + 1; // 17 loops -> 17 * 32 = 544-32 + 6 = 518 
                uint256 mod = (data[i].length + 2) % 32;
                // console.log("loops:", loops);
                // console.log("mod: ", mod);
                _data = LibFunction.paste32Bytes(data[i],_data,30,32 + prevLength);
                prevLength = prevLength + 32;
                uint j = 1;
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
        // get first byte 
        bytes1 length = data[0];

        // use that to determine length of data
        bytes[] memory returnData = new bytes[](uint8(length));

        // get next byte representing length of data: 
        bytes memory dataLength;
        uint256 lengthOfData;
        uint256 startIndex = 2;

        for(uint i; i < returnData.length; i++){
            startIndex = startIndex + lengthOfData + 1; //
            dataLength = data[startIndex - 2 : startIndex];  
            // assembly to load 32 bytes into uint256 
            // note we only need the first 2 bytes, so we shift by 30 bytes
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
        clipBoardType _type,
        uint256 returnDataIndex,
        uint256 copyIndex,
        uint256 pasteIndex
    ) external pure returns (bytes memory stuff) {
        uint256 clipboardData;
        clipboardData = clipboardData | uint256(_type) << 248;
        
        clipboardData = clipboardData 
            | returnDataIndex << 160
            | (copyIndex * 32) + 32 << 80
            | (pasteIndex * 32) + 36;
        if (useEther) {
            // put 0x1 in second byte 
            // shift left 30 bytes
            clipboardData = clipboardData | 1 << 240;
            return abi.encodePacked(clipboardData, amount);
        } else {
            return abi.encodePacked(clipboardData);
        }
    }

    function advancedClipboardHelper(
        bool useEther,
        uint256 amount,
        clipBoardType _type,
        uint256[] calldata returnDataIndex,
        uint256[] calldata copyIndex,
        uint256[] calldata pasteIndex
    ) external pure returns (bytes memory stuff) {
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
        stuff = abi.encodePacked(clipboardData[0]);
        for(uint i = 1; i < clipboardData.length; i++){
            stuff = abi.encodePacked(stuff,clipboardData[i]);
        }
        stuff = abi.encodePacked(stuff,amount);
    }

}
