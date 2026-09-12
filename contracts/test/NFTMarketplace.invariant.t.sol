// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {MockNFT} from "../src/MockNFT.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

/// @notice Drives random list/buy/cancel calls against the marketplace.
contract MarketplaceHandler is Test {
    NFTMarketplace public mkt;
    MockNFT public nft;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    uint256 public constant TOKEN_COUNT = 20;

    constructor(NFTMarketplace mkt_, MockNFT nft_) {
        mkt = mkt_;
        nft = nft_;

        vm.startPrank(seller);
        for (uint256 i = 0; i < TOKEN_COUNT; i++) {
            nft.mint(seller, i);
        }
        nft.setApprovalForAll(address(mkt), true);
        vm.stopPrank();

        vm.deal(buyer, 1_000_000 ether);
    }

    function list(uint256 idSeed, uint256 price) external {
        uint256 id = idSeed % TOKEN_COUNT;
        price = bound(price, 1, 100 ether);

        if (nft.ownerOf(id) != seller) return; // seller no longer holds it
        (address existing,,,) = mkt.listing(address(nft), id);
        if (existing != address(0)) return; // already listed

        vm.prank(seller);
        mkt.listNFT(address(nft), id, price);
    }

    function buy(uint256 idSeed) external {
        uint256 id = idSeed % TOKEN_COUNT;
        (address s,,, uint256 p) = mkt.listing(address(nft), id);
        if (s == address(0)) return;

        vm.prank(buyer);
        mkt.buyNFT{value: p}(address(nft), id);
    }

    function cancel(uint256 idSeed) external {
        uint256 id = idSeed % TOKEN_COUNT;
        (address s,,,) = mkt.listing(address(nft), id);
        if (s != seller) return;

        vm.prank(seller);
        mkt.cancelList(address(nft), id);
    }
}

/// @notice Invariant: the `activeListings` array never desyncs from the `listing` mapping.
contract NFTMarketplaceInvariantTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;
    MarketplaceHandler handler;

    function setUp() public {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();
        handler = new MarketplaceHandler(marketplace, nft);
        targetContract(address(handler));
    }

    /// @dev Every enumerated listing must have price>0 and mirror the direct mapping exactly.
    function invariant_ArrayMirrorsMapping() public view {
        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        for (uint256 i = 0; i < all.length; i++) {
            NFTMarketplace.Listing memory e = all[i];
            assertGt(e.price, 0, "active listing with zero price");

            (address s, address n, uint256 t, uint256 p) = marketplace.listing(e.nftAddress, e.tokenId);
            assertEq(s, e.seller, "seller desync");
            assertEq(n, e.nftAddress, "collection desync");
            assertEq(t, e.tokenId, "tokenId desync");
            assertEq(p, e.price, "price desync");
        }
    }
}
