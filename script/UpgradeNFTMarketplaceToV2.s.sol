// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFTMarketplaceUpgradeable} from "../src/upgradeable/NFTMarketplaceUpgradeable.sol";
import {NFTMarketplaceUpgradeableV2} from "../src/upgradeable/NFTMarketplaceUpgradeableV2.sol";

contract UpgradeNFTMarketplaceToV2 is Script {
    function run() external returns (NFTMarketplaceUpgradeableV2 newImplementation) {
        uint256 upgraderPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("MARKETPLACE_PROXY");

        vm.startBroadcast(upgraderPrivateKey);
        newImplementation = new NFTMarketplaceUpgradeableV2();
        NFTMarketplaceUpgradeable(payable(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopBroadcast();
    }
}
