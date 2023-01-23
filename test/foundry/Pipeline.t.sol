// SPDX-License-Identifier: UNLICENSED
pragma abicoder v2;
pragma solidity <=0.8.13;

import "forge-std/Test.sol";
import {MockToken} from "contracts/mock/MockToken.sol";
import {Depot} from "contracts/Depot.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/interfaces/IPipeline.sol";
import "contracts/interfaces/IBeanstalk.sol";
import "contracts/Staking.sol";

import "./TestHelper.sol";

contract PipelineTest is TestHelper {
    Depot depot;
    address constant OLYMPUS_STAKING = 0xB63cac384247597756545b500253ff8E607a8020;

    function setUp() public {
        deployMockTokens(5);
        initUsers(2);
        depot = new Depot();
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
        bytes memory _return = depot.pipe(_pipeCall);
        console.log("return value:", string(_return));
    }

    function testPipeValues() prank(user) public {
        PipeCall memory _pipeCall;
        bytes memory data = abi.encodeWithSelector(MockToken.mint.selector,user,100);
        _pipeCall.target = address(tokens[0]);
        _pipeCall.data = data;
        bytes memory success = depot.pipe(_pipeCall);
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

        bytes[] memory _return = depot.multiPipe(_pipeCall);
        
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

        bytes[] memory _return = depot.multiPipe(_pipeCall);
        
       assertEq(tokens[0].balanceOf(user), 100);
       assertEq(tokens[1].balanceOf(user), 300);

    }

    function testFarm() prank(user) public {
        // mint and transfer
        tokens[0].approve(address(depot), (2 ** 256 - 1));

        bytes[] memory _farmCalls = new bytes[](2);

        PipeCall memory _pipeCall;
        bytes memory pipeData = abi.encodeWithSelector(MockToken.mint.selector,user,100);
        _pipeCall.target = address(tokens[0]);
        _pipeCall.data = pipeData;

        bytes memory data = abi.encodeWithSelector(
            depot.pipe.selector,
            _pipeCall
        );
        _farmCalls[0] = data;

        bytes memory data1 = abi.encodeWithSelector(
            depot.transferToken.selector,
            tokens[0],
            user2,
            100,
            From.EXTERNAL,
            To.EXTERNAL
        );

        _farmCalls[1] = data1;
        vm.stopPrank();
        bytes[] memory _return = depot.farm(_farmCalls);
        
       assertEq(tokens[0].balanceOf(user2), 100);

    }


    function testOlympus() prank(user) public {

    }
}
