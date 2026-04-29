// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ChainlinkPriceOracle} from "../src/oracle/ChainlinkPriceOracle.sol";

contract DeployChainlinkPriceOracle is Script {
    function run() external returns (ChainlinkPriceOracle oracle) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envOr("ORACLE_OWNER", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);
        oracle = new ChainlinkPriceOracle(owner);
        vm.stopBroadcast();
    }
}
