pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "hardhat/console.sol";


/**
 * @title Classifieds
 * @notice Implements the classifieds board market. The market will be governed
 * by an ERC20 token as currency, and an ERC721 token that represents the
 * ownership of the items being offerd. Only ads for selling items are
 * implemented. The item tokenization is responsibility of the ERC721 contract
 * which should encode any item details.
 */
contract Market is ERC721, ERC721Enumerable, ERC721URIStorage {
    event OfferStatusChange(uint256 ad, bytes32 status);

    IERC20 public currencyToken;
    IERC721 public itemToken;


    using Counters for Counters.Counter;
    Counters.Counter private _licenseIds;

    struct Original {
        address nft;
        uint256 item;
        address owner;
    }

    struct Offer {
        Original original;
        uint256 price;
        bytes32 status; // Open, Executed, Cancelled
    }


    mapping(uint256 => Offer) public offers;

    uint256 offerCounter;

    constructor (address _currencyTokenAddress) ERC721("AuthMint License", "AML")
    public

    {
        currencyToken = IERC20(_currencyTokenAddress);
        offerCounter = 0;

    }

    function getOffers(uint256 from, uint256 size)
    public
    view
    returns (Offer[]  memory)
    {

        Offer[] memory someOffers = new Offer[](size);
        for (uint i = from; i < size; i++) {
            Offer storage offer = offers[i];
            someOffers[i] = offer;
        }
        return (someOffers);
    }

    /**
     * @dev Returns the details for a offer.
     * @param _offer The id for the offer.
     */
    function getOffer(uint256 _offer)
    public
    virtual
    view
    returns (Original memory, uint256, bytes32)
    {
        Offer memory offer = offers[_offer];
        return (offer.original, offer.price, offer.status);
    }



    /**
     * @dev Opens a new offer. Puts _item in escrow.
     * @param _item The id for the item to offer.
     * @param _price The amount of currency for which to offer the item.
     */
    function openOffer(address nftAddress, uint256 _item, uint256 _price)
    public
    virtual
    {
        console.log("Sender %s", msg.sender);
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _item);

        Original memory _original = Original({
            nft : nftAddress,
            item : _item,
            owner : msg.sender
            });

        offers[offerCounter] = Offer({
            original : _original,
            price : _price,
            status : "Open"
            });
        offerCounter += 1;
        emit OfferStatusChange(offerCounter - 1, "Open");
    }


    function buyLicense(uint256 _offer)
    public
    virtual
    returns (uint256)
    {
        Offer memory offer = offers[_offer];
        require(offer.status == "Open", "Offer is not Open.");


        currencyToken.transferFrom(msg.sender, offer.original.owner, offer.price);

        _licenseIds.increment();
        uint256 newItemId = _licenseIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId,  Strings.toString(_offer));

        return newItemId;
    }

    /**
     * @dev Cancels a offer by the owner.
     * @param _offer The offer to be cancelled.
     */
    function cancelOffer(uint256 _offer)
    public
    virtual
    {
        Offer memory offer = offers[_offer];
        require(
            msg.sender == offer.original.owner,
            "Offer can be cancelled only by owner."
        );
        require(offer.status == "Open", "Offer is not Open.");
        itemToken.transferFrom(address(this), offer.original.owner, offer.original.item);
        offers[_offer].status = "Cancelled";
        emit OfferStatusChange(_offer, "Cancelled");
    }



    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}