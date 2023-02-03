// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";

// import {FlashDepot} from ".../contracts/FlashDepot.sol";


// // Script that flash loans OHM, inverse bonds it for DAI,
// // rebuys OHM with DAI,
// // transfers OHM back to vault,
// // stakes remaining OHM to user
// contract ohmFlashScript is Script {
    
//     function run() external {
//         bytes memory data = "";
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
//         vm.startBroadcast(deployerPrivateKey);
//             // deploy depot
//             flashDepot = new FlashDepot();
            
//         vm.stopBroadcast();
//     }
// }