// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";

import {FlashDepot} from "contracts/FlashDepot.sol";
import {FlashDepotAave} from "contracts/FlashDepotAave.sol";
import {TestHelper} from "test/foundry/testHelper.sol";



contract create2 is Script, TestHelper {
    address flashDepot;
    function run() external {
        address flashDepot;
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
            // flash loan DAI, swap to OHM, 
            flashDepot = address(new FlashDepotAave());

            
            
        vm.stopBroadcast();
        console.log("flashDepot deployed at: ", flashDepot);
        console.log("other bytes:");
        console.logBytes(type(FlashDepotAave).creationCode);
        console.log("flashDepot hash");
        console.logBytes32(keccak256(type(FlashDepotAave).creationCode));
    }
}