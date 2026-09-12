// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title NFTMarketplace
/// @notice Minimal escrow-less marketplace: sellers list ERC721s they still hold,
///         buyers pay the exact price and the NFT is pulled from the seller on purchase.
contract NFTMarketplace is ReentrancyGuard {
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

    error ZeroPrice();
    error NotOwner();
    error NotApproved();
    error ListingNotFound();
    error WrongPrice();
    error NotSeller();
    error PaymentFailed();

    event NFTListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NFTCancelled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);
    event NFTSold(
        address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price
    );

    /// @notice List an NFT you own for sale at a fixed price.
    /// @dev Requires the marketplace to be approved for this token so `buyNFT` can pull it.
    /// @param nftAddress_ ERC721 collection address.
    /// @param tokenId_ Token id to sell.
    /// @param price_ Sale price in wei (must be > 0).
    function listNFT(address nftAddress_, uint256 tokenId_, uint256 price_) external nonReentrant {
        if (price_ == 0) revert ZeroPrice();

        address owner_ = IERC721(nftAddress_).ownerOf(tokenId_);
        if (owner_ != msg.sender) revert NotOwner();

        // Fail early: without approval a future buy would revert.
        if (
            IERC721(nftAddress_).getApproved(tokenId_) != address(this)
                && !IERC721(nftAddress_).isApprovedForAll(owner_, address(this))
        ) revert NotApproved();

        Listing memory listing_ =
            Listing({seller: msg.sender, nftAddress: nftAddress_, tokenId: tokenId_, price: price_});

        listing[nftAddress_][tokenId_] = listing_;
        _addToActive(listing_);

        emit NFTListed(msg.sender, nftAddress_, tokenId_, price_);
    }

    /// @notice Buy a listed NFT by paying its exact price.
    /// @param nftAddress_ ERC721 collection address.
    /// @param tokenId_ Token id to buy.
    function buyNFT(address nftAddress_, uint256 tokenId_) external payable nonReentrant {
        Listing memory listing_ = listing[nftAddress_][tokenId_];
        if (listing_.price == 0) revert ListingNotFound();
        if (msg.value != listing_.price) revert WrongPrice();

        // Effects before interactions (checks-effects-interactions).
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
    function getActiveListings() external view returns (Listing[] memory) {
        return activeListings;
    }

    /// @notice Number of active listings.
    function totalListings() external view returns (uint256) {
        return activeListings.length;
    }

    function _addToActive(Listing memory listing_) private {
        activeListings.push(listing_);
        _indexOf[listing_.nftAddress][listing_.tokenId] = activeListings.length; // store index+1
    }

    function _removeFromActive(address nftAddress_, uint256 tokenId_) private {
        uint256 indexPlusOne = _indexOf[nftAddress_][tokenId_];
        if (indexPlusOne == 0) return; // not enumerated; nothing to do
        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = activeListings.length - 1;

        if (index != lastIndex) {
            Listing memory last = activeListings[lastIndex];
            activeListings[index] = last; // swap last into the hole
            _indexOf[last.nftAddress][last.tokenId] = index + 1; // reindex moved item
        }

        activeListings.pop();
        delete _indexOf[nftAddress_][tokenId_];
    }
}
