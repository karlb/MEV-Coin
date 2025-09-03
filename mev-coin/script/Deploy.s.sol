// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MEVCoin.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        
        MEVCoin mevCoin = new MEVCoin();
        
        console.log("MEV-Coin deployed at:", address(mevCoin));
        console.log("Name:", mevCoin.name());
        console.log("Symbol:", mevCoin.symbol());
        console.log("Initial supply:", mevCoin.totalSupply());
        
        vm.stopBroadcast();
    }
}