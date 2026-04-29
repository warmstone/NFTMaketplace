// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NFTMarketplaceUpgradeable} from "../src/upgradeable/NFTMarketplaceUpgradeable.sol";

contract DeployNFTMarketplaceUpgradeable is Script {
    function run() external returns (NFTMarketplaceUpgradeable marketplace, NFTMarketplaceUpgradeable implementation) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);

        vm.startBroadcast(deployerPrivateKey);
        implementation = new NFTMarketplaceUpgradeable();
        bytes memory initData = abi.encodeCall(NFTMarketplaceUpgradeable.initialize, (deployer, feeRecipient));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        marketplace = NFTMarketplaceUpgradeable(address(proxy));
        vm.stopBroadcast();
    }
}
