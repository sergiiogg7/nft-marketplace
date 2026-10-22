// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {NFTMarketplace} from "../../src/NFTMarketplace.sol";

/// @dev Seller contract that cannot receive ETH: payment to it always fails.
contract NoReceiveSeller {
    function list(NFTMarketplace marketplace_, IERC721 nft_, uint256 tokenId_, uint256 price_) external {
        nft_.approve(address(marketplace_), tokenId_);
        marketplace_.listNFT(address(nft_), tokenId_, price_);
    }
}

/// @dev Seller contract that tries to cancel its own listing while being paid.
contract ReentrantSeller {
    NFTMarketplace private _marketplace;
    address private _nft;
    uint256 private _tokenId;

    function list(NFTMarketplace marketplace_, IERC721 nft_, uint256 tokenId_, uint256 price_) external {
        _marketplace = marketplace_;
        _nft = address(nft_);
        _tokenId = tokenId_;
        nft_.approve(address(marketplace_), tokenId_);
        marketplace_.listNFT(address(nft_), tokenId_, price_);
    }

    receive() external payable {
        _marketplace.cancelList(_nft, _tokenId);
    }
}

/// @dev Buyer contract that tries to buy a second token from inside `onERC721Received`.
contract ReentrantBuyer is IERC721Receiver {
    NFTMarketplace private _marketplace;
    address private _nft;
    uint256 private _otherTokenId;
    uint256 private _otherPrice;

    function buy(NFTMarketplace marketplace_, address nft_, uint256 tokenId_, uint256 otherTokenId_, uint256 price_)
        external
        payable
    {
        _marketplace = marketplace_;
        _nft = nft_;
        _otherTokenId = otherTokenId_;
        _otherPrice = price_;
        marketplace_.buyNFT{value: msg.value - price_}(nft_, tokenId_);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        _marketplace.buyNFT{value: _otherPrice}(_nft, _otherTokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
}
