// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract DeployNFTMarketplace is Script {
    function run() external returns (NFTMarketplace marketplace) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);
        marketplace = new NFTMarketplace(feeRecipient);
        vm.stopBroadcast();
    }
}
