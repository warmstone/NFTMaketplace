// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PandaNFT} from "../src/PandaNFT.sol";

contract DeployPandaNFT is Script {
    function run() external returns (PandaNFT pandaNFT) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        pandaNFT = new PandaNFT();
        vm.stopBroadcast();
    }
}
