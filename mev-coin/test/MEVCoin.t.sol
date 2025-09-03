// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MEVCoin.sol";

contract MEVCoinTest is Test {
    MEVCoin public mevCoin;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    
    event MEVBonus(address indexed recipient, uint256 amount, uint256 blockNumber);
    
    function setUp() public {
        mevCoin = new MEVCoin();
    }
    
    function testInitialState() public {
        assertEq(mevCoin.name(), "MEV-Coin");
        assertEq(mevCoin.symbol(), "MEV");
        assertEq(mevCoin.decimals(), 18);
        assertEq(mevCoin.totalSupply(), 0);
    }
    
    function testTransferOnNonDivisibleBlock() public {
        vm.roll(99);
        
        mevCoin.transfer(alice, 0);
        
        assertEq(mevCoin.balanceOf(alice), 0);
        assertEq(mevCoin.totalSupply(), 0);
        assertFalse(mevCoin.hasBlockBeenMinted(99));
    }
    
    function testFirstTransferOnDivisibleBlock() public {
        vm.roll(100);
        
        vm.expectEmit(true, false, false, true);
        emit MEVBonus(alice, 100 * 10**18, 100);
        
        mevCoin.transfer(alice, 0);
        
        assertEq(mevCoin.balanceOf(alice), 100 * 10**18);
        assertEq(mevCoin.totalSupply(), 100 * 10**18);
        assertTrue(mevCoin.hasBlockBeenMinted(100));
    }
    
    function testSecondTransferOnSameDivisibleBlock() public {
        vm.roll(200);
        
        mevCoin.transfer(alice, 0);
        
        uint256 aliceBalanceAfterFirst = mevCoin.balanceOf(alice);
        assertEq(aliceBalanceAfterFirst, 100 * 10**18);
        
        mevCoin.transfer(bob, 0);
        
        assertEq(mevCoin.balanceOf(bob), 0);
        assertEq(mevCoin.balanceOf(alice), 100 * 10**18);
        assertEq(mevCoin.totalSupply(), 100 * 10**18);
    }
    
    function testMultipleDivisibleBlocks() public {
        vm.roll(100);
        mevCoin.transfer(alice, 0);
        assertEq(mevCoin.balanceOf(alice), 100 * 10**18);
        
        vm.roll(200);
        mevCoin.transfer(bob, 0);
        assertEq(mevCoin.balanceOf(bob), 100 * 10**18);
        
        vm.roll(300);
        mevCoin.transfer(charlie, 0);
        assertEq(mevCoin.balanceOf(charlie), 100 * 10**18);
        
        assertEq(mevCoin.totalSupply(), 300 * 10**18);
    }
    
    function testTransferWithActualAmount() public {
        vm.roll(100);
        
        mevCoin.transfer(alice, 0);
        uint256 aliceInitialBalance = mevCoin.balanceOf(alice);
        assertEq(aliceInitialBalance, 100 * 10**18);
        
        vm.roll(101);
        vm.prank(alice);
        mevCoin.transfer(bob, 50 * 10**18);
        
        assertEq(mevCoin.balanceOf(alice), 50 * 10**18);
        assertEq(mevCoin.balanceOf(bob), 50 * 10**18);
        assertEq(mevCoin.totalSupply(), 100 * 10**18);
    }
    
    function testTransferFromWithMEVBonus() public {
        vm.roll(100);
        
        mevCoin.transfer(alice, 0);
        assertEq(mevCoin.balanceOf(alice), 100 * 10**18);
        
        vm.prank(alice);
        mevCoin.approve(address(this), 50 * 10**18);
        
        vm.roll(200);
        mevCoin.transferFrom(alice, bob, 50 * 10**18);
        
        assertEq(mevCoin.balanceOf(alice), 50 * 10**18);
        assertEq(mevCoin.balanceOf(bob), 50 * 10**18 + 100 * 10**18);
        assertEq(mevCoin.totalSupply(), 200 * 10**18);
    }
    
    function testZeroValueTransfersAllowed() public {
        vm.roll(100);
        
        mevCoin.transfer(alice, 0);
        assertEq(mevCoin.balanceOf(alice), 100 * 10**18);
        
        vm.roll(101);
        vm.prank(alice);
        mevCoin.transfer(bob, 0);
        
        assertEq(mevCoin.balanceOf(alice), 100 * 10**18);
        assertEq(mevCoin.balanceOf(bob), 0);
        assertEq(mevCoin.totalSupply(), 100 * 10**18);
    }
    
    function testEdgeCasesForBlockNumbers() public {
        uint256[] memory testBlocks = new uint256[](5);
        testBlocks[0] = 0;
        testBlocks[1] = 100;
        testBlocks[2] = 1000;
        testBlocks[3] = 99900;
        testBlocks[4] = 100000;
        
        address[] memory recipients = new address[](5);
        recipients[0] = address(0x10);
        recipients[1] = address(0x11);
        recipients[2] = address(0x12);
        recipients[3] = address(0x13);
        recipients[4] = address(0x14);
        
        for (uint256 i = 0; i < testBlocks.length; i++) {
            vm.roll(testBlocks[i]);
            mevCoin.transfer(recipients[i], 0);
            assertEq(mevCoin.balanceOf(recipients[i]), 100 * 10**18);
        }
        
        assertEq(mevCoin.totalSupply(), 500 * 10**18);
    }
    
    function testNonDivisibleBlocksNoMinting() public {
        uint256[] memory nonDivisibleBlocks = new uint256[](4);
        nonDivisibleBlocks[0] = 99;
        nonDivisibleBlocks[1] = 101;
        nonDivisibleBlocks[2] = 199;
        nonDivisibleBlocks[3] = 201;
        
        for (uint256 i = 0; i < nonDivisibleBlocks.length; i++) {
            vm.roll(nonDivisibleBlocks[i]);
            address recipient = address(uint160(0x100 + i));
            mevCoin.transfer(recipient, 0);
            assertEq(mevCoin.balanceOf(recipient), 0);
            assertFalse(mevCoin.hasBlockBeenMinted(nonDivisibleBlocks[i]));
        }
        
        assertEq(mevCoin.totalSupply(), 0);
    }
    
    function testHasBlockBeenMintedFunction() public {
        assertFalse(mevCoin.hasBlockBeenMinted(100));
        assertFalse(mevCoin.hasBlockBeenMinted(200));
        
        vm.roll(100);
        mevCoin.transfer(alice, 0);
        assertTrue(mevCoin.hasBlockBeenMinted(100));
        assertFalse(mevCoin.hasBlockBeenMinted(200));
        
        vm.roll(200);
        mevCoin.transfer(bob, 0);
        assertTrue(mevCoin.hasBlockBeenMinted(100));
        assertTrue(mevCoin.hasBlockBeenMinted(200));
    }
}