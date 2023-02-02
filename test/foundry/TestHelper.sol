/**
 * SPDX-License-Identifier: MIT
 **/
pragma solidity <0.8.17;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockToken} from "contracts/mock/MockToken.sol";
import {Users} from "utils/Users.sol";
import {Pipeline} from "contracts/Pipeline.sol";

abstract contract TestHelper is Test {
    using Strings for uint;

    Users users;
    address user;
    address user2;

    IERC20[] tokens; // Mock token addresses sorted lexicographically


    function initUsers() internal {
        users = new Users();
        address[] memory _user = new address[](2);
        _user = users.createUsers(2);
        user = _user[0];
        user2 = _user[1];
    }

    function initPipeline() internal {
        Pipeline _pipeline = new Pipeline();
        vm.etch(0xb1bE0000bFdcDDc92A8290202830C4Ef689dCeaa, at(address(_pipeline)));
    }


    /// @dev deploy `n` mock ERC20 tokens and sort by address
    function deployMockTokens(uint n) internal {
        IERC20[] memory _tokens = new IERC20[](n);
        for (uint i = 0; i < n; i++) {
            IERC20 temp = IERC20(
                new MockToken(
                    string(abi.encodePacked("Token ", i.toString())), // name
                    string(abi.encodePacked("TOKEN", i.toString())) // symbol
                )
            );
            // Insertion sort
            uint j;
            if (i > 0) {
                for (j = i; j >= 1 && temp < _tokens[j - 1]; j--)
                    _tokens[j] = _tokens[j - 1];
                _tokens[j] = temp;
            } else _tokens[0] = temp;
        }
        for (uint i = 0; i < n; i++) tokens.push(_tokens[i]);
    }

    /// @dev mint mock tokens to each recipient
    function mintTokens(address recipient, uint amount) internal {
        for (uint i = 0; i < tokens.length; i++)
            MockToken(address(tokens[i])).mint(recipient, amount);
    }

    /// @dev approve `spender` to use `owner` tokens
    function approveMaxTokens(address owner, address spender) prank(owner) internal {
        for (uint i = 0; i < tokens.length; i++)
            tokens[i].approve(spender, type(uint).max);
    }

    /// @dev gets the first `n` mock tokens
    function getTokens(uint n)
        internal
        view
        returns (IERC20[] memory _tokens)
    {
        _tokens = new IERC20[](n);
        for (uint i; i < n; ++i) {
            _tokens[i] = tokens[i];
        }
    }

    modifier prank(address from) {
        vm.startPrank(from);
        _;
        vm.stopPrank();
    }

    //gets bytecode at specific address (cant use address.code as we're in 0.7.6)
    function at(address _addr) public view returns (bytes memory o_code) {
        assembly {
            // retrieve the size of the code
            let size := extcodesize(_addr)
            // allocate output byte array
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }
}
