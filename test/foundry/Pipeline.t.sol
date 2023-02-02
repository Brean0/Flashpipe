// SPDX-License-Identifier: UNLICENSED
pragma abicoder v2;
pragma solidity <=0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockToken} from "contracts/mock/MockToken.sol";
import {MockContract} from "contracts/mock/MockContract.sol";
import {FlashDepot} from "contracts/FlashDepot.sol";
import "contracts/interfaces/IPipeline.sol";
import "contracts/interfaces/IBeanstalk.sol";
import {OlympusStaking} from "contracts/Staking.sol";

import "./TestHelper.sol";

contract FlashDepotTest is TestHelper {
    FlashDepot flashDepot;
    MockContract mockContract;
    address constant OLYMPUS_STAKING = 0xB63cac384247597756545b500253ff8E607a8020;
    address constant PIPELINE = 0xb1bE0000bFdcDDc92A8290202830C4Ef689dCeaa;
    address constant FIXEDTERMBOND = 0x007F7735baF391e207E3aA380bb53c4Bd9a5Fed6;

    function setUp() public {
        deployMockTokens(5);
        initUsers(2);
        initPipeline(); 
        flashDepot = new FlashDepot();
        mockContract = new MockContract();
    }

    function testAAA() public {
        assertEq(ERC20(address(tokens[0])).symbol(), "TOKEN1");
        assertEq(ERC20(address(tokens[0])).name(), "Token 1");
        assertEq(ERC20(address(tokens[1])).symbol(), "TOKEN0");
        assertEq(ERC20(address(tokens[1])).name(), "Token 0");
    }

    function testPipeNoValues() prank(user) public {
        PipeCall memory _pipeCall;
        bytes memory data = abi.encodeWithSelector(ERC20.symbol.selector);
        _pipeCall.target = address(tokens[0]);
        _pipeCall.data = data;
        bytes memory _return = flashDepot.pipe(_pipeCall);
        console.log("return value:", string(_return));
    }

    function testPipeValues() prank(user) public {
        PipeCall memory _pipeCall;
        bytes memory data = abi.encodeWithSelector(MockToken.mint.selector,user,100);
        _pipeCall.target = address(tokens[0]);
        _pipeCall.data = data;
        bytes memory success = flashDepot.pipe(_pipeCall);
        bool _success;
        assembly {
            _success := mload(add(success,0x20))
        }
        console.log("success:", _success);
        assertEq(tokens[0].balanceOf(user),100);
    }

    function testMultiPipeNoValues() prank(user) public {
        PipeCall[] memory _pipeCall = new PipeCall[](4);
        bytes memory dataSymbol = abi.encodeWithSelector(ERC20.symbol.selector);
        bytes memory dataName = abi.encodeWithSelector(ERC20.name.selector);

        _pipeCall[0].target = address(tokens[0]);
        _pipeCall[0].data = dataSymbol;
        _pipeCall[1].target = address(tokens[0]);
        _pipeCall[1].data = dataName;
        _pipeCall[2].target = address(tokens[1]);
        _pipeCall[2].data = dataSymbol;
        _pipeCall[3].target = address(tokens[1]);
        _pipeCall[3].data = dataName;

        bytes[] memory _return = flashDepot.multiPipe(_pipeCall);
        
        for(uint i; i < _pipeCall.length; ++i){
            console.log("return value:", string(_return[i]));
        }
    }

    function testMultiPipeValues() prank(user) public {
        PipeCall[] memory _pipeCall = new PipeCall[](4);
        bytes memory data = abi.encodeWithSelector(MockToken.mint.selector,user,100);

        _pipeCall[0].target = address(tokens[0]);
        _pipeCall[0].data = data;
        _pipeCall[1].target = address(tokens[1]);
        _pipeCall[1].data = data;
        _pipeCall[2].target = address(tokens[1]);
        _pipeCall[2].data = data;
        _pipeCall[3].target = address(tokens[1]);
        _pipeCall[3].data = data;

        flashDepot.multiPipe(_pipeCall);
        
        assertEq(tokens[0].balanceOf(user), 100);
        assertEq(tokens[1].balanceOf(user), 300);
    }

    function testFarm() prank(user) public {
        // mint and transfer
        tokens[0].approve(address(flashDepot), (2 ** 256 - 1));

        bytes[] memory _farmCalls = new bytes[](2);

        PipeCall memory _pipeCall;
        bytes memory pipeData = abi.encodeWithSelector(MockToken.mint.selector,user,100);
        _pipeCall.target = address(tokens[0]);
        _pipeCall.data = pipeData;

        bytes memory data = abi.encodeWithSelector(
            flashDepot.pipe.selector,
            _pipeCall
        );
        _farmCalls[0] = data;

        bytes memory data1 = abi.encodeWithSelector(
            flashDepot.transferToken.selector,
            tokens[0],
            user2,
            100,
            From.EXTERNAL,
            To.EXTERNAL
        );

        _farmCalls[1] = data1;
        flashDepot.farm(_farmCalls);
        
       assertEq(tokens[0].balanceOf(user2), 100);

    }


    // tests here require forking as we use the balancer Vault
    function testFlashLoanNoDataRevert() prank(user) public {
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = IERC20(DAI);
        amounts[0] = 1e18;
        vm.expectRevert("BAL#515");
        flashDepot.flashPipe(
            tokens,
            amounts,
            ""
        );
    }

    function testFlashLoanStaticData() prank(user) public {
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = IERC20(DAI);
        amounts[0] = 1000e18;

        //user deposits DAI into a mock contract, withdraws the same amount
        // wrap pipe call into farm calls
        bytes[] memory _farmCalls = new bytes[](1);
        
        // transfer asset into pipeline
        // bytes memory data1 = abi.encodeWithSelector(
        //     flashDepot.transferToken.selector,
        //     tokens[0],
        //     pipeline,
        //     100,
        //     From.EXTERNAL,
        //     To.EXTERNAL
        // );
        // _farmCalls[0] = data;


        PipeCall[] memory _pipeCall = new PipeCall[](4);

        bytes memory pipeData = abi.encodeWithSelector(IERC20(DAI).approve.selector,mockContract,amounts[0]);
        _pipeCall[0].target = address(IERC20(DAI));
        _pipeCall[0].data = pipeData;

        pipeData = abi.encodeWithSelector(MockContract.deposit.selector,tokens[0],amounts[0]);
        _pipeCall[1].target = address(mockContract);
        _pipeCall[1].data = pipeData;

        pipeData = abi.encodeWithSelector(MockContract.withdraw.selector,tokens[0],amounts[0]);
        _pipeCall[2].target = address(mockContract);
        _pipeCall[2].data = pipeData;

        pipeData = abi.encodeWithSelector(IERC20(DAI).transfer.selector,vault,amounts[0]);
        _pipeCall[3].target = address(IERC20(DAI));
        _pipeCall[3].data = pipeData;

        bytes memory data = abi.encodeWithSelector(
            flashDepot.multiPipe.selector,
            _pipeCall
        );
        _farmCalls[0] = data;
        // convert farmcalls into bytes
        bytes memory flashData = flashDepot.convertByteArrayToBytes(_farmCalls);
        flashDepot.flashPipe(
            tokens,
            amounts,
            flashData
        );
    }
}
