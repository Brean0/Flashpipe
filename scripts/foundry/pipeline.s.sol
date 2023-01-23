// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";

// import {Pipeline} from "../src/aquifers/Aquifer.sol";


// // Script to deploy a BEAN-ETH {Well}, 
// // with a constant product pricing function
// // and MockPump via an aquifer.
// contract Pipeline is Script {
//     using SafeERC20 for IERC20;
    
//     function run() external {
//         bytes memory data = "";
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//         IERC20[] memory tokens = new IERC20[](2);
//         tokens[0] = new MockToken("Token0","TK0",18); 
//         tokens[1] = new MockToken("Token1","TK1",18); 
        
//         // deploy Aquifer/Auger 
//         Aquifer aquifer = new Aquifer();
//         Auger auger = new Auger();
//         // deploy pump/wellFunction/Tokens 
//         MockPump mockPump = new MockPump();
//         ConstantProduct2 cp2 = new ConstantProduct2();
//         // create calls
//         Call[] memory mockPumpCall = new Call[](1);
//         mockPumpCall[0].target = address(mockPump);
//         mockPumpCall[0].data = data;
        
//         Call memory cp2Call;
//         cp2Call.target = address(cp2);
//         cp2Call.data = data;

//         //bore well
//         address well = aquifer.boreWell(
//             tokens,
//             cp2Call,
//             mockPumpCall,
//             auger);

//         vm.stopBroadcast();
//     }
// }