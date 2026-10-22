// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MockNFT} from "./mocks/MockNFT.sol";
import {NoReceiveSeller, ReentrantSeller, ReentrantBuyer} from "./mocks/Actors.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;

    address seller = vm.addr(1);
    address buyer = vm.addr(2);
    address other = vm.addr(3);
    uint256 constant TOKEN_ID = 0;
    uint256 constant PRICE = 1 ether;

    function setUp() public {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();
        nft.mint(seller, TOKEN_ID);
    }

    /// @dev Approve and list `id` at `price` as `who`.
    function _list(address who, uint256 id, uint256 price) internal {
        vm.startPrank(who);
        nft.approve(address(marketplace), id);
        marketplace.listNFT(address(nft), id, price);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // listNFT
    // -------------------------------------------------------------------------

    function test_listNFT_withZeroCollection_revertsWithZeroAddress() external {
        // Arrange / Act / Assert
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.ZeroAddress.selector);
        marketplace.listNFT(address(0), TOKEN_ID, PRICE);
    }

    function test_listNFT_withZeroPrice_revertsWithZeroPrice() external {
        // Arrange
        vm.startPrank(seller);
        nft.approve(address(marketplace), TOKEN_ID);

        // Act / Assert
        vm.expectRevert(NFTMarketplace.ZeroPrice.selector);
        marketplace.listNFT(address(nft), TOKEN_ID, 0);
        vm.stopPrank();
    }

    function test_listNFT_byNonOwner_revertsWithNotOwner() external {
        // Arrange
        nft.mint(other, 1);

        // Act / Assert
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.NotOwner.selector);
        marketplace.listNFT(address(nft), 1, PRICE);
    }

    function test_listNFT_withoutApproval_revertsWithNotApproved() external {
        // Arrange / Act / Assert
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.NotApproved.selector);
        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);
    }

    function test_listNFT_withApprovedToken_addsToActiveListings() external {
        // Arrange / Act
        _list(seller, TOKEN_ID, PRICE);

        // Assert
        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        assertEq(marketplace.totalListings(), 1);
        assertEq(all.length, 1);
        assertEq(all[0].seller, seller);
        assertEq(all[0].nftAddress, address(nft));
        assertEq(all[0].tokenId, TOKEN_ID);
        assertEq(all[0].price, PRICE);
    }

    function test_listNFT_withApprovalForAll_addsToActiveListings() external {
        // Arrange
        vm.startPrank(seller);
        nft.setApprovalForAll(address(marketplace), true);

        // Act
        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);
        vm.stopPrank();

        // Assert
        assertEq(marketplace.totalListings(), 1);
    }

    function test_listNFT_emitsNFTListed() external {
        // Arrange
        vm.startPrank(seller);
        nft.approve(address(marketplace), TOKEN_ID);
        vm.expectEmit(true, true, true, true);
        emit NFTMarketplace.NFTListed(seller, address(nft), TOKEN_ID, PRICE);

        // Act
        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);
        vm.stopPrank();
    }

    function test_listNFT_whenAlreadyListed_updatesPriceWithoutDuplicate() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);

        // Act
        vm.prank(seller);
        marketplace.listNFT(address(nft), TOKEN_ID, 2 ether);

        // Assert
        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        assertEq(all.length, 1);
        assertEq(all[0].price, 2 ether);
        (,,, uint256 price) = marketplace.listing(address(nft), TOKEN_ID);
        assertEq(price, 2 ether);
    }

    function test_listNFT_afterRelist_cancelLeavesNoGhostEntry() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.prank(seller);
        marketplace.listNFT(address(nft), TOKEN_ID, 2 ether);

        // Act
        vm.prank(seller);
        marketplace.cancelList(address(nft), TOKEN_ID);

        // Assert
        assertEq(marketplace.totalListings(), 0);
        assertEq(marketplace.getActiveListings().length, 0);
    }

    function test_listNFT_byNewOwnerOfStaleListing_replacesSeller() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.prank(seller);
        nft.transferFrom(seller, other, TOKEN_ID);

        // Act
        _list(other, TOKEN_ID, 3 ether);

        // Assert
        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        assertEq(all.length, 1);
        assertEq(all[0].seller, other);
        assertEq(all[0].price, 3 ether);
    }

    // -------------------------------------------------------------------------
    // cancelList
    // -------------------------------------------------------------------------

    function test_cancelList_bySeller_removesListing() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);

        // Act
        vm.prank(seller);
        marketplace.cancelList(address(nft), TOKEN_ID);

        // Assert
        assertEq(marketplace.totalListings(), 0);
        (address listedSeller,,,) = marketplace.listing(address(nft), TOKEN_ID);
        assertEq(listedSeller, address(0));
    }

    function test_cancelList_emitsNFTCancelled() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.expectEmit(true, true, true, false);
        emit NFTMarketplace.NFTCancelled(seller, address(nft), TOKEN_ID);

        // Act
        vm.prank(seller);
        marketplace.cancelList(address(nft), TOKEN_ID);
    }

    function test_cancelList_byNonSeller_revertsWithNotSeller() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);

        // Act / Assert
        vm.prank(other);
        vm.expectRevert(NFTMarketplace.NotSeller.selector);
        marketplace.cancelList(address(nft), TOKEN_ID);
    }

    function test_cancelList_whenNotListed_revertsWithNotSeller() external {
        // Arrange / Act / Assert
        vm.prank(seller);
        vm.expectRevert(NFTMarketplace.NotSeller.selector);
        marketplace.cancelList(address(nft), TOKEN_ID);
    }

    function test_cancelList_ofMiddleListing_keepsArrayConsistent() external {
        // Arrange
        nft.mint(seller, 1);
        nft.mint(seller, 2);
        _list(seller, 0, 1 ether);
        _list(seller, 1, 2 ether);
        _list(seller, 2, 3 ether);

        // Act
        vm.prank(seller);
        marketplace.cancelList(address(nft), 1);

        // Assert
        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        assertEq(all.length, 2);
        assertEq(all[0].tokenId, 0);
        assertEq(all[1].tokenId, 2);

        vm.deal(buyer, 3 ether);
        vm.prank(buyer);
        marketplace.buyNFT{value: 3 ether}(address(nft), 2);
        assertEq(marketplace.totalListings(), 1);
        assertEq(marketplace.getActiveListings()[0].tokenId, 0);
    }

    // -------------------------------------------------------------------------
    // buyNFT
    // -------------------------------------------------------------------------

    function test_buyNFT_whenNotListed_revertsWithListingNotFound() external {
        // Arrange
        vm.deal(buyer, PRICE);

        // Act / Assert
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.ListingNotFound.selector);
        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
    }

    function test_buyNFT_withLowerValue_revertsWithWrongPrice() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.deal(buyer, PRICE);

        // Act / Assert
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketplace.WrongPrice.selector, PRICE, PRICE - 1));
        marketplace.buyNFT{value: PRICE - 1}(address(nft), TOKEN_ID);
    }

    function test_buyNFT_withHigherValue_revertsWithWrongPrice() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.deal(buyer, PRICE + 1);

        // Act / Assert
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketplace.WrongPrice.selector, PRICE, PRICE + 1));
        marketplace.buyNFT{value: PRICE + 1}(address(nft), TOKEN_ID);
    }

    function test_buyNFT_withExactPrice_transfersNftAndPaysSeller() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.deal(buyer, PRICE);
        uint256 sellerBalanceBefore = seller.balance;

        // Act
        vm.prank(buyer);
        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        // Assert
        assertEq(nft.ownerOf(TOKEN_ID), buyer);
        assertEq(seller.balance, sellerBalanceBefore + PRICE);
        assertEq(address(marketplace).balance, 0);
        assertEq(marketplace.totalListings(), 0);
        (address listedSeller,,,) = marketplace.listing(address(nft), TOKEN_ID);
        assertEq(listedSeller, address(0));
    }

    function test_buyNFT_emitsNFTSold() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.deal(buyer, PRICE);
        vm.expectEmit(true, true, true, true);
        emit NFTMarketplace.NFTSold(buyer, seller, address(nft), TOKEN_ID, PRICE);

        // Act
        vm.prank(buyer);
        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
    }

    function test_buyNFT_afterCancel_revertsWithListingNotFound() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.prank(seller);
        marketplace.cancelList(address(nft), TOKEN_ID);
        vm.deal(buyer, PRICE);

        // Act / Assert
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.ListingNotFound.selector);
        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
    }

    function test_buyNFT_whenSellerMovedTheNft_revertsAndKeepsListing() external {
        // Arrange
        _list(seller, TOKEN_ID, PRICE);
        vm.prank(seller);
        nft.transferFrom(seller, other, TOKEN_ID);
        vm.deal(buyer, PRICE);

        // Act / Assert
        vm.prank(buyer);
        vm.expectRevert();
        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
        assertEq(marketplace.totalListings(), 1);
        assertEq(buyer.balance, PRICE);
    }

    function test_buyNFT_whenSellerCannotReceiveEth_revertsWithPaymentFailed() external {
        // Arrange
        NoReceiveSeller badSeller = new NoReceiveSeller();
        nft.mint(address(badSeller), 7);
        badSeller.list(marketplace, nft, 7, PRICE);
        vm.deal(buyer, PRICE);

        // Act / Assert
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.PaymentFailed.selector);
        marketplace.buyNFT{value: PRICE}(address(nft), 7);
        assertEq(nft.ownerOf(7), address(badSeller));
    }

    function test_buyNFT_whenSellerReentersCancel_revertsWithPaymentFailed() external {
        // Arrange
        ReentrantSeller evilSeller = new ReentrantSeller();
        nft.mint(address(evilSeller), 8);
        evilSeller.list(marketplace, nft, 8, PRICE);
        vm.deal(buyer, PRICE);

        // Act / Assert
        vm.prank(buyer);
        vm.expectRevert(NFTMarketplace.PaymentFailed.selector);
        marketplace.buyNFT{value: PRICE}(address(nft), 8);
    }

    function test_buyNFT_whenBuyerReentersDuringTransfer_revertsWithReentrancyGuard() external {
        // Arrange
        nft.mint(seller, 1);
        _list(seller, TOKEN_ID, PRICE);
        _list(seller, 1, PRICE);
        ReentrantBuyer evilBuyer = new ReentrantBuyer();
        vm.deal(address(this), 2 * PRICE);

        // Act / Assert
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        evilBuyer.buy{value: 2 * PRICE}(marketplace, address(nft), TOKEN_ID, 1, PRICE);
    }

    // -------------------------------------------------------------------------
    // getActiveListingsPage
    // -------------------------------------------------------------------------

    function _listMany(uint256 count_) internal {
        for (uint256 i = 0; i < count_; i++) {
            nft.mint(seller, 100 + i);
            _list(seller, 100 + i, PRICE + i);
        }
    }

    function test_getActiveListingsPage_withValidRange_returnsSlice() external {
        // Arrange
        _listMany(5);

        // Act
        NFTMarketplace.Listing[] memory page = marketplace.getActiveListingsPage(1, 3);

        // Assert
        assertEq(page.length, 3);
        assertEq(page[0].tokenId, 101);
        assertEq(page[2].tokenId, 103);
    }

    function test_getActiveListingsPage_withLimitPastEnd_truncates() external {
        // Arrange
        _listMany(5);

        // Act
        NFTMarketplace.Listing[] memory page = marketplace.getActiveListingsPage(3, 10);

        // Assert
        assertEq(page.length, 2);
        assertEq(page[1].tokenId, 104);
    }

    function test_getActiveListingsPage_withOffsetPastEnd_returnsEmpty() external {
        // Arrange
        _listMany(2);

        // Act / Assert
        assertEq(marketplace.getActiveListingsPage(2, 5).length, 0);
        assertEq(marketplace.getActiveListingsPage(99, 5).length, 0);
    }

    function test_getActiveListingsPage_withZeroLimit_returnsEmpty() external {
        // Arrange
        _listMany(2);

        // Act / Assert
        assertEq(marketplace.getActiveListingsPage(0, 0).length, 0);
    }

    function test_getActiveListingsPage_withMaxLimit_doesNotOverflow() external {
        // Arrange
        _listMany(3);

        // Act
        NFTMarketplace.Listing[] memory page = marketplace.getActiveListingsPage(1, type(uint256).max);

        // Assert
        assertEq(page.length, 2);
    }
}
