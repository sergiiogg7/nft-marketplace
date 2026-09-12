// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MockNFT} from "../src/MockNFT.sol";

/// @notice Local deploy: marketplace + a demo NFT collection with a few minted tokens.
/// @dev Uses Anvil account #0 by default; override with `PRIVATE_KEY` env var.
contract DeployLocal is Script {
    // Anvil's well-known account #0 private key (local only, never real funds).
    uint256 constant DEFAULT_ANVIL_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        uint256 pk = vm.envOr("PRIVATE_KEY", DEFAULT_ANVIL_PK);
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        NFTMarketplace marketplace = new NFTMarketplace();
        MockNFT nft = new MockNFT();

        // Mint tokenIds 0,1,2 to the deployer so the UI has something to list.
        for (uint256 i = 0; i < 3; i++) {
            nft.mint(deployer, i);
        }

        vm.stopBroadcast();

        console.log("NFTMarketplace :", address(marketplace));
        console.log("MockNFT        :", address(nft));
        console.log("Owner (tokens 0,1,2):", deployer);
    }
}
