// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract NFTMarketplaceScript is Script {
    NFTMarketplace public marketplace;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        marketplace = new NFTMarketplace();

        vm.stopBroadcast();
    }
}
