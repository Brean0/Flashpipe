// SPDX-License-Identifier: UNLICENSED
pragma abicoder v2;
pragma solidity <=0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Depot} from "contracts/Depot.sol";
import {LibFlashLoan} from "libraries/LibFlashLoan.sol";
import "contracts/interfaces/IPipeline.sol";
import "contracts/interfaces/IBeanstalk.sol";
import "contracts/interfaces/IWETH.sol";

import "./TestHelper.sol";

contract UnbanksyPOC is TestHelper {
    Depot depot;
    IWETH weth;
    address constant OLYMPUS_STAKING = 0xB63cac384247597756545b500253ff8E607a8020;
    address constant PIPELINE = 0xb1bE0000bFdcDDc92A8290202830C4Ef689dCeaa;
    address gOHM = 0x0ab87046fBb341D058F17CBC4c1133F25a20a52f;
    address OHM = 0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5;
    address OHMFRAXBP = 0x5271045F7B73c17825A7A7aee6917eE46b0B7520;
    address yOHMFRAXBP = 0x7788A5492bc948e1d8c2caa53b2e0a60ed5403b0;
    
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address FRAXBPPOOL = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address FRAXROUTER = 0x25e9acA5951262241290841b6f863d59D37DC4f0;
    address CVXFPIS = 0xfA87DB3EAa93B7293021e38416650D2E666bC483;
    address FPIS = 0xc2544A32872A91F4A553b404C6950e89De901fdb;



    function setUp() public {
        deployMockTokens(5);
        initUsers();
        initPipeline(); 
        depot = new Depot();
        weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }

    function testUnBanksyPipeline() prank(user) public {
        // POC tx that: 
        // 1: unstakes gOHM -> OHM
        // 2: LPs OHM into OHM-FRAXBP pool 
        // 3: deposits OHM-FRAXBP yearn vault
        vm.pauseGasMetering(); // disable gas metering for calculating gas costs

        // deal 100 gOHM to the user:
        deal(address(gOHM), user, 1e18);
        
        AdvancedPipeCall[] memory _advancedPipeCall = new AdvancedPipeCall[](4);

        // unstake gOHM -> OHM
        bytes memory data = abi.encodeWithSignature(
            "unstake(address,uint256,bool,bool)",
            address(PIPELINE),
            1e18,
            false,
            false
        );
        _advancedPipeCall[0].target = OLYMPUS_STAKING;
        _advancedPipeCall[0].callData = data;
        _advancedPipeCall[0].clipboard = abi.encodePacked(uint256(0));
        
        // LP OHM into OHM-FRAXBP pool
        // we want to take the first output from the last call (the amount of OHM we got:)
        data = abi.encodeWithSignature(
            "add_liquidity(uint256[2],uint256,bool)",
            [ uint256(264976083918), 0], // TODO: this can be taken from clipboard, but needs some finessing
            uint256(0),
            false
        );
        _advancedPipeCall[1].target = address(0xFc1e8bf3E81383Ef07Be24c3FD146745719DE48D); // curve
        _advancedPipeCall[1].callData = data;
        _advancedPipeCall[1].clipboard = abi.encodePacked(uint256(0));

        // deposit into yearn vault
        // we want to get the amount of OHM-FRAXBP we got from the last call
        data = abi.encodeWithSignature(
            "deposit(address,address,uint256)",
            address(0x7788A5492bc948e1d8c2caa53b2e0a60ed5403b0), // OHMFRAXBP yearn vault
            address(0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52), // parther vault ??
            0 // this is the amount, but since we're getting it from the 2nd call, it is set to 0 (as its being overriden anyways)
        );

        bytes memory clipData = LibFlashLoan.clipboardHelper(
            false,
            0,
            LibFlashLoan.Type.singlePaste,
            1, // we want the returnData from the 2nd call
            0, // the 1st output 
            2 // to the 3rd input
        );
        _advancedPipeCall[2].target = address(0x8ee392a4787397126C163Cb9844d7c447da419D8); // yearn vault thing
        _advancedPipeCall[2].callData = data;
        _advancedPipeCall[2].clipboard = clipData;

        // unload pipeline, and send the amt back to the user
        // we want to take the first output from the last call (the amount of OHM we got:)
        data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            address(user), // send it back to the user
            uint256(0) // this is the yOHMFRAXBP amt, but we use the clipboard to get it from the prev call
        );

        clipData = LibFlashLoan.clipboardHelper(
            false,
            0,
            LibFlashLoan.Type.singlePaste,
            2, // we want the returnData from the 3rd call
            0, // the 1st output 
            1 // to the 2nd input
        );
        _advancedPipeCall[3].target = address(yOHMFRAXBP); // ERC20 token
        _advancedPipeCall[3].callData = data;
        _advancedPipeCall[3].clipboard = clipData;

        bytes[] memory _farmCalls = new bytes[](2);
        // load gOHM into pipeline
        bytes memory data0 = abi.encodeWithSelector(
                depot.transferToken.selector,
                IERC20(gOHM),
                address(PIPELINE),
                1e18,
                From.EXTERNAL,
                To.EXTERNAL
            );
        _farmCalls[0] = data0;

        // do pipeline stuff
        bytes memory data1 = abi.encodeWithSelector(
                depot.advancedPipe.selector,
                _advancedPipeCall,
                0
            );
        _farmCalls[1] = data1;
        
        // approve gOHM for depot: 
        IERC20(gOHM).approve(address(depot), 1000e18);

        // pipeline can pre-approve contracts, so that future callers can omit the approval step.  
        PipeCall[] memory _pipeCall = new PipeCall[](2);
        _pipeCall[0].target = address(OHM);
        // approve curve for max gOHM
        _pipeCall[0].data = abi.encodeWithSignature(
            "approve(address,uint256)", 
            address(0xFc1e8bf3E81383Ef07Be24c3FD146745719DE48D), 
            2 ** 256 - 1
        );
        // approve the yearn vault for max OHMFRAXBP
        _pipeCall[1].target = address(OHMFRAXBP);
        _pipeCall[1].data = abi.encodeWithSignature(
            "approve(address,uint256)", 
            address(0x8ee392a4787397126C163Cb9844d7c447da419D8), 
            2 ** 256 - 1
        );
        depot.multiPipe(_pipeCall);
        console.log("user's balance of gOHM before: ", IERC20(gOHM).balanceOf(user));
        console.log("user's balance of yOHMFRAX-BP before: ", IERC20(yOHMFRAXBP).balanceOf(user));

        vm.resumeGasMetering(); // resume gas costs

        // convert farmcalls into bytes
        depot.farm(_farmCalls);

        vm.pauseGasMetering(); // resume gas costs
        console.log("user's balance of gOHM after: ", IERC20(gOHM).balanceOf(user));
        console.log("user's balance of yOHMFRAX-BP after: ", IERC20(yOHMFRAXBP).balanceOf(user));
        vm.resumeGasMetering();
    }

    function testUnBanksyNoPipeline() prank(user) public {
        // POC tx that: 
        // 1: unstakes gOHM -> OHM
        // 2: LPs OHM into OHM-FRAXBP pool 
        // 3: deposits OHM-FRAXBP yearn vault
        vm.pauseGasMetering(); // disable gas metering for calculating gas costs

        // deal 100 gOHM to the user:
        deal(address(gOHM), user, 1e18);
        console.log("user's balance of gOHM before: ", IERC20(gOHM).balanceOf(user));
        console.log("user's balance of yOHMFRAX-BP before: ", IERC20(yOHMFRAXBP).balanceOf(user));

        vm.resumeGasMetering(); // resume gas costs
        // approve gOHM for unstaking
        IERC20(gOHM).approve(OLYMPUS_STAKING, 1000e18); // 1
        // unstake gOHM -> OHM
        OLYMPUS_STAKING.call(
            abi.encodeWithSignature(
                "unstake(address,uint256,bool,bool)",
                address(user),
                1e18,
                false,
                false
            )
        ); // 2

        // approve OHM for curve

        IERC20(OHM).approve(
            address(0xFc1e8bf3E81383Ef07Be24c3FD146745719DE48D), 
            1000e18
        ); // 3
        // LP OHM into OHM-FRAXBP pool

        address(0xFc1e8bf3E81383Ef07Be24c3FD146745719DE48D).call(
            abi.encodeWithSignature(
                "add_liquidity(uint256[2],uint256,bool)",
                [ uint256(264976083918), 0],
                uint256(0),
                false
            )
        ); // 4 

        IERC20(OHMFRAXBP).approve(
            address(0x8ee392a4787397126C163Cb9844d7c447da419D8), 
            1000e18
        ); // 5

        address(0x8ee392a4787397126C163Cb9844d7c447da419D8).call(
            abi.encodeWithSignature(
                "deposit(address,address,uint256)",
                address(0x7788A5492bc948e1d8c2caa53b2e0a60ed5403b0), // OHMFRAXBP yearn vault
                address(0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52), // parther vault ??
                427118414574078207231
            )
        ); // 6 

        vm.pauseGasMetering(); // resume gas costs
        console.log("user's balance of gOHM after: ", IERC20(gOHM).balanceOf(user));
        console.log("user's balance of yOHMFRAX-BP after: ", IERC20(yOHMFRAXBP).balanceOf(user));
        vm.resumeGasMetering();
    }
}
