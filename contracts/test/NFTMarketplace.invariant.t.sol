// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {MockNFT} from "./mocks/MockNFT.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

/// @notice Drives random list, relist, buy and cancel calls against the marketplace.
contract MarketplaceHandler is Test {
    NFTMarketplace public mkt;
    MockNFT public nft;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    uint256 public constant TOKEN_COUNT = 20;

    uint256 public ghostEthPaid;
    uint256 public ghostSales;

    constructor(NFTMarketplace mkt_, MockNFT nft_) {
        mkt = mkt_;
        nft = nft_;

        vm.startPrank(seller);
        for (uint256 i = 0; i < TOKEN_COUNT; i++) {
            nft.mint(seller, i);
        }
        nft.setApprovalForAll(address(mkt), true);
        vm.stopPrank();

        vm.prank(buyer);
        nft.setApprovalForAll(address(mkt), true);
        vm.deal(buyer, 1_000_000 ether);
    }

    // Lists a token, or relists it at a new price if it is already listed. Current owner is the seller.
    function list(uint256 idSeed_, uint256 price_) external {
        uint256 id = idSeed_ % TOKEN_COUNT;
        price_ = bound(price_, 1, 100 ether);

        vm.prank(nft.ownerOf(id));
        mkt.listNFT(address(nft), id, price_);
    }

    function buy(uint256 idSeed_) external {
        uint256 id = idSeed_ % TOKEN_COUNT;
        (address listedSeller,,, uint256 price) = mkt.listing(address(nft), id);
        if (listedSeller == address(0) || nft.ownerOf(id) != listedSeller) return;
        if (listedSeller == buyer) return;

        vm.prank(buyer);
        mkt.buyNFT{value: price}(address(nft), id);

        ghostEthPaid += price;
        ghostSales++;
    }

    function cancel(uint256 idSeed_) external {
        uint256 id = idSeed_ % TOKEN_COUNT;
        (address listedSeller,,,) = mkt.listing(address(nft), id);
        if (listedSeller == address(0)) return;

        vm.prank(listedSeller);
        mkt.cancelList(address(nft), id);
    }

    // Moves the token back to the seller so the buyer can list it again later.
    function returnToSeller(uint256 idSeed_) external {
        uint256 id = idSeed_ % TOKEN_COUNT;
        if (nft.ownerOf(id) != buyer) return;

        vm.prank(buyer);
        nft.transferFrom(buyer, seller, id);
    }
}

/// @notice Invariants: the enumeration array never desyncs from the mapping and the contract keeps no ETH.
contract NFTMarketplaceInvariantTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;
    MarketplaceHandler handler;

    function setUp() external {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();
        handler = new MarketplaceHandler(marketplace, nft);
        targetContract(address(handler));
    }

    // Every enumerated listing must have price > 0 and mirror the direct mapping exactly.
    function invariant_arrayMirrorsMapping() external view {
        NFTMarketplace.Listing[] memory all = marketplace.getActiveListings();
        for (uint256 i = 0; i < all.length; i++) {
            NFTMarketplace.Listing memory entry = all[i];
            assertGt(entry.price, 0);

            (address s, address n, uint256 t, uint256 p) = marketplace.listing(entry.nftAddress, entry.tokenId);
            assertEq(s, entry.seller);
            assertEq(n, entry.nftAddress);
            assertEq(t, entry.tokenId);
            assertEq(p, entry.price);
        }
    }

    // Each listed token appears exactly once in the array, so the array length equals the listed count.
    function invariant_noDuplicateEntries() external view {
        uint256 listed;
        for (uint256 id = 0; id < handler.TOKEN_COUNT(); id++) {
            (address s,,,) = marketplace.listing(address(nft), id);
            if (s != address(0)) listed++;
        }
        assertEq(marketplace.totalListings(), listed);
    }

    // The marketplace forwards every payment to the seller, so it never keeps ETH.
    function invariant_marketplaceHoldsNoEth() external view {
        assertEq(address(marketplace).balance, 0);
    }

    // Every sale moved exactly its price out of the buyer: the buyer balance matches the ghost accounting.
    function invariant_buyerSpendMatchesGhostAccounting() external view {
        assertEq(address(handler.buyer()).balance, 1_000_000 ether - handler.ghostEthPaid());
    }
}
