// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";

import {FlashDepot} from "contracts/FlashDepot.sol";
import {FlashDepotAave} from "contracts/FlashDepotAave.sol";



contract OhmFlash is Script {
    address flashDepot = 0x000000000000cb991C1aB267427ddbC16d2c26C0;
    function run() external {
        
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
            // flash loan DAI, swap to OHM, 
            new FlashDepotAave();
            
        vm.stopBroadcast();
        console.log("flashDepot deployed at: ", flashDepot);
    }
}