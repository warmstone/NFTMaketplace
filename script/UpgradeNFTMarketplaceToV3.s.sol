// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFTMarketplaceUpgradeable} from "../src/upgradeable/NFTMarketplaceUpgradeable.sol";
import {NFTMarketplaceUpgradeableV3} from "../src/upgradeable/NFTMarketplaceUpgradeableV3.sol";

contract UpgradeNFTMarketplaceToV3 is Script {
    function run() external returns (NFTMarketplaceUpgradeableV3 newImplementation) {
        uint256 upgraderPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("MARKETPLACE_PROXY");
        address priceOracle = vm.envAddress("PRICE_ORACLE");

        vm.startBroadcast(upgraderPrivateKey);
        newImplementation = new NFTMarketplaceUpgradeableV3();
        bytes memory initData = abi.encodeCall(NFTMarketplaceUpgradeableV3.initializeV3, (priceOracle));
        NFTMarketplaceUpgradeable(payable(proxy)).upgradeToAndCall(address(newImplementation), initData);
        vm.stopBroadcast();
    }
}
