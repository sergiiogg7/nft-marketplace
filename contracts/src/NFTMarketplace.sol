// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title NFTMarketplace
/// @notice Minimal escrow-less marketplace: sellers list ERC721s they still hold,
///         buyers pay the exact price and the NFT is pulled from the seller on purchase.
/// @dev Listings are not escrowed, so a listing can become stale if the seller transfers the NFT or
///      revokes the approval. A stale listing cannot be bought (the transfer reverts) and only its seller
///      can cancel it. Re-listing a token updates its existing entry instead of creating a second one.
contract NFTMarketplace is ReentrancyGuard {
    /// @notice Data stored for each active listing.
    /// @param seller Account that created the listing and receives the payment.
    /// @param nftAddress ERC721 collection address.
    /// @param tokenId Token being sold.
    /// @param price Sale price in wei.
    struct Listing {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
    }

    /// @notice Direct lookup of a listing by (collection, tokenId).
    mapping(address => mapping(uint256 => Listing)) public listing;

    /// @notice All active listings, for cheap on-chain enumeration by a frontend.
    Listing[] public activeListings;

    /// @dev (collection, tokenId) => index+1 in `activeListings` (0 means "not listed").
    mapping(address => mapping(uint256 => uint256)) private _indexOf;

    /// @notice Thrown when the collection address is the zero address.
    error ZeroAddress();

    /// @notice Thrown when the listing price is zero.
    error ZeroPrice();

    /// @notice Thrown when the caller does not own the token being listed.
    error NotOwner();

    /// @notice Thrown when the marketplace is not approved to transfer the token being listed.
    error NotApproved();

    /// @notice Thrown when no listing exists for the requested token.
    error ListingNotFound();

    /// @notice Thrown when the ETH sent does not equal the listing price.
    /// @param expected The listing price.
    /// @param provided The ETH amount sent with the purchase.
    error WrongPrice(uint256 expected, uint256 provided);

    /// @notice Thrown when the caller is not the seller of the listing.
    error NotSeller();

    /// @notice Thrown when the ETH payment to the seller fails.
    error PaymentFailed();

    /// @notice Emitted when an NFT is listed or its listing is updated.
    /// @param seller Account that created the listing.
    /// @param nftAddress ERC721 collection address.
    /// @param tokenId Token being sold.
    /// @param price Sale price in wei.
    event NFTListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);

    /// @notice Emitted when a seller cancels a listing.
    /// @param seller Account that cancelled.
    /// @param nftAddress ERC721 collection address.
    /// @param tokenId Token whose listing was removed.
    event NFTCancelled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);

    /// @notice Emitted when an NFT is sold.
    /// @param buyer Account that paid and received the NFT.
    /// @param seller Account that received the payment.
    /// @param nftAddress ERC721 collection address.
    /// @param tokenId Token that was sold.
    /// @param price Price paid in wei.
    event NFTSold(
        address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price
    );

    /// @notice List an NFT you own for sale at a fixed price, or update the price of an existing listing.
    /// @dev Requires the marketplace to be approved for this token so `buyNFT` can pull it.
    ///      If the token is already listed, its entry is overwritten in place (new seller and price).
    /// @param nftAddress_ ERC721 collection address.
    /// @param tokenId_ Token id to sell.
    /// @param price_ Sale price in wei (must be > 0).
    function listNFT(address nftAddress_, uint256 tokenId_, uint256 price_) external nonReentrant {
        if (nftAddress_ == address(0)) revert ZeroAddress();
        if (price_ == 0) revert ZeroPrice();

        address owner_ = IERC721(nftAddress_).ownerOf(tokenId_);
        if (owner_ != msg.sender) revert NotOwner();

        if (
            IERC721(nftAddress_).getApproved(tokenId_) != address(this)
                && !IERC721(nftAddress_).isApprovedForAll(owner_, address(this))
        ) revert NotApproved();

        Listing memory listing_ =
            Listing({seller: msg.sender, nftAddress: nftAddress_, tokenId: tokenId_, price: price_});

        listing[nftAddress_][tokenId_] = listing_;

        uint256 indexPlusOne = _indexOf[nftAddress_][tokenId_];
        if (indexPlusOne == 0) _addToActive(listing_);
        else activeListings[indexPlusOne - 1] = listing_;

        emit NFTListed(msg.sender, nftAddress_, tokenId_, price_);
    }

    /// @notice Buy a listed NFT by paying its exact price.
    /// @param nftAddress_ ERC721 collection address.
    /// @param tokenId_ Token id to buy.
    function buyNFT(address nftAddress_, uint256 tokenId_) external payable nonReentrant {
        Listing memory listing_ = listing[nftAddress_][tokenId_];
        if (listing_.price == 0) revert ListingNotFound();
        if (msg.value != listing_.price) revert WrongPrice(listing_.price, msg.value);

        delete listing[nftAddress_][tokenId_];
        _removeFromActive(nftAddress_, tokenId_);

        IERC721(nftAddress_).safeTransferFrom(listing_.seller, msg.sender, listing_.tokenId);

        (bool success,) = listing_.seller.call{value: msg.value}("");
        if (!success) revert PaymentFailed();

        emit NFTSold(msg.sender, listing_.seller, nftAddress_, tokenId_, listing_.price);
    }

    /// @notice Cancel a listing you created.
    /// @param nftAddress_ ERC721 collection address.
    /// @param tokenId_ Token id whose listing to remove.
    function cancelList(address nftAddress_, uint256 tokenId_) external nonReentrant {
        Listing memory listing_ = listing[nftAddress_][tokenId_];
        if (listing_.seller != msg.sender) revert NotSeller();

        delete listing[nftAddress_][tokenId_];
        _removeFromActive(nftAddress_, tokenId_);

        emit NFTCancelled(msg.sender, nftAddress_, tokenId_);
    }

    /// @notice Return every active listing (for a frontend grid).
    /// @dev Unbounded. Use {getActiveListingsPage} when the number of listings can be large.
    /// @return All active listings.
    function getActiveListings() external view returns (Listing[] memory) {
        return activeListings;
    }

    /// @notice Return a slice of the active listings.
    /// @dev Returns an empty array when `offset_` is past the end, and truncates `limit_` to what remains.
    /// @param offset_ Index of the first listing to return.
    /// @param limit_ Maximum number of listings to return.
    /// @return page The requested slice of active listings.
    function getActiveListingsPage(uint256 offset_, uint256 limit_) external view returns (Listing[] memory page) {
        uint256 total = activeListings.length;
        if (offset_ >= total) return page;

        uint256 remaining = total - offset_;
        uint256 count = limit_ < remaining ? limit_ : remaining;

        page = new Listing[](count);
        for (uint256 i = 0; i < count; i++) {
            page[i] = activeListings[offset_ + i];
        }
    }

    /// @notice Number of active listings.
    /// @return Length of the active listings array.
    function totalListings() external view returns (uint256) {
        return activeListings.length;
    }

    /// @dev Appends a listing to `activeListings` and records its index+1.
    function _addToActive(Listing memory listing_) private {
        activeListings.push(listing_);
        _indexOf[listing_.nftAddress][listing_.tokenId] = activeListings.length;
    }

    /// @dev Swap-and-pop removal that keeps `_indexOf` in sync for the moved element.
    ///      Only called for tokens with an active listing, which always have a non-zero `_indexOf`.
    function _removeFromActive(address nftAddress_, uint256 tokenId_) private {
        uint256 indexPlusOne = _indexOf[nftAddress_][tokenId_];
        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = activeListings.length - 1;

        if (index != lastIndex) {
            Listing memory last = activeListings[lastIndex];
            activeListings[index] = last;
            _indexOf[last.nftAddress][last.tokenId] = index + 1;
        }

        activeListings.pop();
        delete _indexOf[nftAddress_][tokenId_];
    }
}
