// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {MockNFT} from "../src/MockNFT.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;

    address seller = vm.addr(1);
    address buyer = vm.addr(2);
    address other = vm.addr(3);
    uint256 constant TOKEN_ID = 0;
    uint256 constant PRICE = 1 ether;

    event NFTSold(
        address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price
    );

    function setUp() public {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();
        nft.mint(seller, TOKEN_ID); // seller owns token 0
    }

    /// @dev Approve + list `id` at `price` as `who`.
    function _list(address who, uint256 id, uint256 price) internal {
        vm.startPrank(who);
        nft.approve(address(marketplace), id);
        marketplace.listNFT(address(nft), id, price);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- listing

    function test_MintSetup() public view {
        assertEq(nft.ownerOf(TOKEN_ID), seller);
    }

    function test_Revert_WhenPriceZero() public {
        vm.startPrank(seller);
        nft.approve(address(marketplace), TOKEN_ID);
        vm.expectRevert(NFTMarketplace.ZeroPrice.selector);
        marketplace.listNFT(address(nft), TOKEN_ID, 0);
        vm.stopPrank();
    }

    function test_Revert_WhenNotOwner() public {
        uint256 otherToken = 1;
        nft.mint(other, otherToken);

        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.NotOwner.selector);
        marketplace.listNFT(address(nft), otherToken, PRICE);
    }

    function test_Revert_WhenNotApproved() public {
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.NotApproved.selector);
        marketplace.listNFT(address(nft), TOKEN_ID, PRICE); // no approve first
    }

    function test_List_AddsToActiveListings() public {
        assertEq(marketplace.totalListings(), 0);

        _list(seller, TOKEN_ID, PRICE);

        assertEq(marketplace.totalListings(), 1);
        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        assertEq(all.length, 1);
        assertEq(all[0].seller, seller);
        assertEq(all[0].tokenId, TOKEN_ID);
        assertEq(all[0].price, PRICE);
    }

    function test_List_WorksWithApprovalForAll() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);
        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);
        vm.stopPrank();

        assertEq(marketplace.totalListings(), 1);
    }

    // ---------------------------------------------------------------- cancel

    function test_Cancel_RemovesFromActive() public {
        _list(seller, TOKEN_ID, PRICE);

        vm.prank(seller);
        marketplace.cancelList(address(nft), TOKEN_ID);

        assertEq(marketplace.totalListings(), 0);
        (address s,,,) = marketplace.listing(address(nft), TOKEN_ID);
        assertEq(s, address(0));
    }

    function test_Revert_Cancel_WhenNotSeller() public {
        _list(seller, TOKEN_ID, PRICE);

        vm.prank(other);
        vm.expectRevert(NFTMarketplace.NotSeller.selector);
        marketplace.cancelList(address(nft), TOKEN_ID);
    }

    // ---------------------------------------------------------------- buy

    function test_Revert_Buy_WhenListingNotFound() public {
        vm.deal(buyer, PRICE);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.ListingNotFound.selector);
        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
    }

    function test_Revert_Buy_WhenWrongPrice() public {
        _list(seller, TOKEN_ID, PRICE);

        vm.deal(buyer, PRICE);
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.WrongPrice.selector);
        marketplace.buyNFT{value: PRICE - 1}(address(nft), TOKEN_ID);
    }

    function test_Buy_TransfersAndPaysAndEmits() public {
        _list(seller, TOKEN_ID, PRICE);

        vm.deal(buyer, PRICE);
        uint256 sellerBalBefore = seller.balance;

        vm.expectEmit(true, true, true, true);
        emit NFTSold(buyer, seller, address(nft), TOKEN_ID, PRICE);

        vm.prank(buyer);
        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        assertEq(nft.ownerOf(TOKEN_ID), buyer, "NFT moved to buyer");
        assertEq(seller.balance, sellerBalBefore + PRICE, "seller paid");
        assertEq(marketplace.totalListings(), 0, "listing removed");
        (address s,,,) = marketplace.listing(address(nft), TOKEN_ID);
        assertEq(s, address(0));
    }

    // ---------------------------------------------------- swap-pop enumeration

    function test_SwapPop_MiddleRemovalKeepsArrayConsistent() public {
        // seller owns 0,1,2 and lists all three
        nft.mint(seller, 1);
        nft.mint(seller, 2);
        _list(seller, 0, 1 ether);
        _list(seller, 1, 2 ether);
        _list(seller, 2, 3 ether);
        assertEq(marketplace.totalListings(), 3);

        // cancel the middle one (token 1)
        vm.prank(seller);
        marketplace.cancelList(address(nft), 1);

        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        assertEq(all.length, 2);
        // token 2 was swapped into index 1; token 0 stays at index 0
        assertEq(all[0].tokenId, 0);
        assertEq(all[1].tokenId, 2);

        // token 1 fully gone from the direct mapping too
        (address s,,,) = marketplace.listing(address(nft), 1);
        assertEq(s, address(0));

        // the moved item (token 2) is still buyable via its key -> index stayed in sync
        vm.deal(buyer, 3 ether);
        vm.prank(buyer);
        marketplace.buyNFT{value: 3 ether}(address(nft), 2);
        assertEq(marketplace.totalListings(), 1);
        assertEq(marketplace.getActiveListings()[0].tokenId, 0);
    }
}
