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


    using Counters for Counters.Counter;
    Counters.Counter private _licenseCounter;
    Counters.Counter private _offerCounter;
    Counters.Counter private _propertyCounter;

    struct Property {
        address nft;
        uint256 item;
        address owner;
    }

    struct Offer {
        uint256 propertyId;
        uint256 price;
        bytes32 status; // Open, Executed, Cancelled
    }


    mapping(uint256 => Property) public properties;
    mapping(uint256 => Offer) public offers;



    constructor (address _currencyTokenAddress) ERC721("AuthMint License", "AML")
    public
    {
        currencyToken = IERC20(_currencyTokenAddress);

    }

    function getProperties(uint256 from, uint256 size)
    public
    view
    returns (Property[] memory)
    {

        Property[] memory someProperties = new Property[](size);

        for (uint i = from; i < size; i++) {
            Property memory property = properties[i];
            someOffers[i] = property;
        }
        return (someProperties);
    }

    function getOffers(uint256 from, uint256 size)
    public
    view
    returns (Offer[]  memory, Property[] memory)
    {

        Offer[] memory someOffers = new Offer[](size);
        Property[] memory someProperties = new Property[](size);

        for (uint i = from; i < size; i++) {

            //TODO: memory or storage?
            Offer storage offer = offers[i];
            someOffers[i] = offer;
            someProperties[i] = properties[offer.propertyId];
        }
        return (someOffers, someProperties);
    }

    /**
     * @dev Returns the details for a offer.
     * @param _offerId The id for the offer.
     */
    function getOffer(uint256 _offerId)
    public
    virtual
    view
    returns (Offer memory, Property memory)
    {
        Offer memory offer = offers[_offerId];
        Property memory property = properties[offer.propertyId];
        return (offer, property);
    }


    function deposit(address nftAddress, uint256 _item)
    public
    returns (uint256)
    {
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _item);
        Property memory _property = Property({
            nft : nftAddress,
            item : _item,
            owner : msg.sender
            });

        _propertyCounter.increment();
        uint256 newPropertyId = _propertyCounter.current();
        properties[newPropertyId] = _property;
        return newPropertyId;
    }


    function withdraw(uint256 _propertyId)
    public
    {
        Property memory _property = properties[_propertyId];
        if (_property.owner == msg.sender) {
            IERC721(_property.nft).transferFrom(address(this), msg.sender, _property.item);

        } else {
            //TODO throw exception
        }

    }


    function openOffer(uint256 _propertyId, uint256 _price)
    public
    virtual
    {
        _offerCounter.increment();
        uint256 newOfferId = _offerCounter.current();

        offers[newOfferId] = Offer({
            propertyId : _propertyId,
            price : _price,
            status : "Open"
            });
        emit OfferStatusChange(newOfferId, "Open");
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
        uint256 _propertyId = deposit(address(this), _item);
        openOffer(_propertyId, _price);
    }


    function mintLicense(uint256 _offer)
    public
    virtual
    returns (uint256)
    {
        Offer memory offer = offers[_offer];
        require(offer.status == "Open", "Offer is not Open.");
        Property memory property = properties[offer.propertyId];
        currencyToken.transferFrom(msg.sender, property.owner, offer.price);

        _licenseCounter.increment();
        uint256 newItemId = _licenseCounter.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, Strings.toString(_offer));

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
        Property memory property = properties[offer.propertyId];
        require(
            msg.sender == property.owner,
            "Offer can be cancelled only by owner."
        );
        require(offer.status == "Open", "Offer is not Open.");

        //TODO: withdraw nft
        //        itemToken.transferFrom(address(this), offer.property.owner, offer.property.item);
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