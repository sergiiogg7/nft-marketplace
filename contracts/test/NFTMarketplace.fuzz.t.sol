// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {MockNFT} from "./mocks/MockNFT.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract NFTMarketplaceFuzz is Test {
    NFTMarketplace marketplace;
    MockNFT nft;

    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");

    function setUp() external {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();
    }

    function _mintAndList(uint256 id_, uint256 price_) internal {
        nft.mint(seller, id_);
        vm.startPrank(seller);
        nft.approve(address(marketplace), id_);
        marketplace.listNFT(address(nft), id_, price_);
        vm.stopPrank();
    }

    // Any positive price and token id must settle with an exact-price purchase.
    function testFuzz_buyNFT_withExactPrice_settles(uint96 price_, uint256 tokenId_) external {
        // Arrange
        price_ = uint96(bound(price_, 1, type(uint96).max));
        _mintAndList(tokenId_, price_);
        vm.deal(buyer, price_);
        uint256 sellerBalanceBefore = seller.balance;

        // Act
        vm.prank(buyer);
        marketplace.buyNFT{value: price_}(address(nft), tokenId_);

        // Assert
        assertEq(nft.ownerOf(tokenId_), buyer);
        assertEq(seller.balance, sellerBalanceBefore + price_);
        assertEq(address(marketplace).balance, 0);
        assertEq(marketplace.totalListings(), 0);
    }

    // Any value different from the listing price must revert with WrongPrice.
    function testFuzz_buyNFT_withWrongValue_revertsWithWrongPrice(uint96 price_, uint96 sent_) external {
        // Arrange
        price_ = uint96(bound(price_, 1, type(uint96).max));
        vm.assume(sent_ != price_);
        _mintAndList(0, price_);
        vm.deal(buyer, sent_);

        // Act / Assert
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketplace.WrongPrice.selector, uint256(price_), uint256(sent_)));
        marketplace.buyNFT{value: sent_}(address(nft), 0);
    }

    // Relisting the same token any number of times never creates more than one entry.
    function testFuzz_listNFT_relistedManyTimes_keepsSingleEntry(uint8 times_, uint96 price_) external {
        // Arrange
        times_ = uint8(bound(times_, 1, 20));
        price_ = uint96(bound(price_, 1, type(uint96).max));
        _mintAndList(0, price_);

        // Act
        for (uint256 i = 0; i < times_; i++) {
            vm.prank(seller);
            marketplace.listNFT(address(nft), 0, price_ + i);
        }

        // Assert
        assertEq(marketplace.totalListings(), 1);
    }

    // A page never exceeds the requested limit nor the remaining items.
    function testFuzz_getActiveListingsPage_neverExceedsBounds(uint8 count_, uint256 offset_, uint256 limit_) external {
        // Arrange
        count_ = uint8(bound(count_, 0, 15));
        for (uint256 i = 0; i < count_; i++) {
            _mintAndList(i, 1 ether);
        }

        // Act
        NFTMarketplace.Listing[] memory page = marketplace.getActiveListingsPage(offset_, limit_);

        // Assert
        uint256 remaining = offset_ >= count_ ? 0 : count_ - offset_;
        uint256 expected = limit_ < remaining ? limit_ : remaining;
        assertEq(page.length, expected);
    }
}
