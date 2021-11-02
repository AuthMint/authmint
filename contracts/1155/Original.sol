// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC1155MixedFungibleMintable.sol";
import "hardhat/console.sol";

/**
 * @dev {ERC1155} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract Original is Context, Ownable, ERC1155MixedFungibleMintable {

    enum ContentStatuses { Unpublished, FirstSell, Sell, NotForSale }

    struct ContentMetadata {
        uint256 price;
        ContentStatuses status;
    }

    mapping(uint256 => ContentMetadata) public metadata;

    // in 1/10000
    uint256 public protocolCommission;

    // type -> in 1/10000
    mapping(uint256 => uint256) public typeCommissions;

    event Sale(uint256 id, address seller, address buyer, uint256 price);

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE` to the account that
     * deploys the contract.
     */
    constructor(string memory uri, uint256 _pc) ERC1155MixedFungibleMintable(uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        protocolCommission = _pc;
    }

    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC1155-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) public virtual {
        require(hasRole(bytes32(id), _msgSender()), "ChessContent#mint: must have minter role to mint");

        _mint(to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(address to, uint256 id, uint256 quantity, bytes memory data) public virtual {
        require(hasRole(bytes32(id), _msgSender()), "ChessContent#mintBatch: must have minter role to mint");

        uint256[] memory ids = new uint256[](quantity);
        uint256[] memory amounts = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; ++i) {

            // Index are 1-based.
            uint256 index = maxIndex[id] + 1;
            maxIndex[id] = index;
            uint256 newId  = id | index;
            nfOwners[id] = to;

            ids[i] = newId;
            amounts[i] = 1;
        }
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * Set type commision
     */
    function setTypeCommission(uint256 id, uint256 commision) public {
        require(nfOwners[id] == _msgSender(), "ChessContent#setMetadata: only owner");
        typeCommissions[id] = commision;
    }

    function getTypeCommission(uint256 id) public view returns (uint256) {
        return typeCommissions[id];
    }

    /**
     * Set price and status
     */
    function setMetadata(uint256 id, ContentMetadata memory _metadata) public {
        require(nfOwners[id] == _msgSender(), "ChessContent#setMetadata: only owner");
        metadata[id] = _metadata;
    }

    function getMetadata(uint256 id) public view returns (ContentMetadata memory) {
        return metadata[id];
    }

    /**
     * buy: buy the nft
     */
    function buy(uint256 id, address buyer) public payable {
        // must be a copy
        uint256 index = getNonFungibleIndex(id);

        uint256 nfType = getNonFungibleBaseType(id);

        require(index != 0, "ChessContent#buy: cannot buy master");

        // must be on sale
        ContentMetadata memory cm = metadata[id];
        require(cm.status == ContentStatuses.FirstSell
        || cm.status == ContentStatuses.Sell, "ChessContent#buy: not for sale");

        // price must be more than 0 wei
        require(cm.price > 0, "ChessContent#buy: Price not set");

        // price must match
        require(msg.value == cm.price, "ChessContent#buy: price dont match");

        uint256 protocolFee = protocolCommission * msg.value / 10000;
        uint256 creatorFee = typeCommissions[nfType] * msg.value / 10000;
        uint256 payment = msg.value - protocolFee - creatorFee;
        address creator = creators[nfType];
        address nftOwner = nfOwners[id];
        address protocol = owner();

        metadata[id] = ContentMetadata({ price: cm.price, status: ContentStatuses.NotForSale });

        safeTransferFrom(nftOwner, buyer, id, 1, msg.data);

        payable(protocol).transfer(protocolFee);
        payable(creator).transfer(creatorFee);
        payable(nftOwner).transfer(payment);

        emit Sale(id, nftOwner, buyer, msg.value);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155MixedFungibleMintable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}