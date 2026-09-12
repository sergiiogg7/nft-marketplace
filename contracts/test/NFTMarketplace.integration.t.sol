// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {MockNFT} from "../src/MockNFT.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

/// @notice End-to-end scenarios exercising list -> buy -> cancel across multiple actors.
contract NFTMarketplaceIntegrationTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;

    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");

    function setUp() public {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();
    }

    function _mintAndList(address who, uint256 id, uint256 price) internal {
        nft.mint(who, id);
        vm.startPrank(who);
        nft.approve(address(marketplace), id);
        marketplace.listNFT(address(nft), id, price);
        vm.stopPrank();
    }

    function test_FullHappyPath() public {
        uint256 price = 2 ether;
        _mintAndList(seller, 0, price);

        vm.deal(buyer, price);
        uint256 sellerBefore = seller.balance;

        vm.prank(buyer);
        marketplace.buyNFT{value: price}(address(nft), 0);

        // NFT moved, ETH moved, listing gone.
        assertEq(nft.ownerOf(0), buyer);
        assertEq(seller.balance, sellerBefore + price);
        assertEq(buyer.balance, 0);
        assertEq(marketplace.totalListings(), 0);
    }

    function test_MultiListing_BuyMiddle_CancelOther_LeavesSurvivor() public {
        _mintAndList(seller, 0, 1 ether);
        _mintAndList(seller, 1, 2 ether);
        _mintAndList(seller, 2, 3 ether);
        assertEq(marketplace.totalListings(), 3);

        // buyer takes the middle listing (token 1)
        vm.deal(buyer, 2 ether);
        vm.prank(buyer);
        marketplace.buyNFT{value: 2 ether}(address(nft), 1);

        // seller cancels token 2
        vm.prank(seller);
        marketplace.cancelList(address(nft), 2);

        // only token 0 survives, and it is internally consistent
        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        assertEq(all.length, 1);
        assertEq(all[0].tokenId, 0);
        assertEq(all[0].seller, seller);
        assertEq(nft.ownerOf(1), buyer);
        assertEq(nft.ownerOf(2), seller);
    }

    // ------------------------------------------------------------------ fuzz

    /// @dev For arbitrary price/tokenId, a list then exact-price buy always settles.
    function testFuzz_listAndBuy(uint96 price, uint256 tokenId) public {
        vm.assume(price > 0);

        _mintAndList(seller, tokenId, price);

        vm.deal(buyer, price);
        uint256 sellerBefore = seller.balance;

        vm.prank(buyer);
        marketplace.buyNFT{value: price}(address(nft), tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(seller.balance, sellerBefore + price);
        assertEq(marketplace.totalListings(), 0);
    }
}
