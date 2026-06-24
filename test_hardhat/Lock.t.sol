// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Lock} from "../contracts/Lock.sol";

contract LockTest is Test {
    Lock public lock;

    address public deployer = vm.addr(uint256(keccak256("deployer")));

    function setUp() public {
        vm.deal(deployer, 1000 ether);

        vm.startPrank(deployer);
        lock = new Lock{value: 100 ether}(block.timestamp + 60 days);
        vm.stopPrank();
    }

    function test_BlockInfo() public view {
        console.log("block chainid: ", block.chainid);
        console.log("block number: ", block.number);
        console.log("block timestamp: ", block.timestamp);
        console.log("block gaslimit: ", block.gaslimit);
        console.log("block basefee: ", block.basefee);
        console.log("block prevrandao: ", block.prevrandao);
    }

    function test_Lock() public {
        address owner = lock.owner();
        assertEq(owner, deployer);

        // TODO: Set timestamp
        vm.warp(block.timestamp + 61 days);
        vm.startPrank(owner);
        lock.withdraw();
        vm.stopPrank();
    }
}

// yarn hardhat test solidity test_hardhat/Lock.t.sol -vvv
