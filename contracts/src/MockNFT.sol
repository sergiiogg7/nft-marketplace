// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

/// @title MockNFT
/// @notice Minimal mintable ERC721 used for local testing and demo listings.
/// @dev Open `mint` on purpose — test/demo only, never deploy to a real network.
contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    /// @notice Mint `tokenId_` to `to_`.
    function mint(address to_, uint256 tokenId_) external {
        _mint(to_, tokenId_);
    }
}
