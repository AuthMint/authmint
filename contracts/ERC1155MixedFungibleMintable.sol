// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./ERC1155MixedFungible.sol";
import "hardhat/console.sol";

/**
    @dev Mintable form of ERC1155
    Shows how easy it is to mint new items
*/
contract ERC1155MixedFungibleMintable is AccessControlEnumerable, ERC1155MixedFungible {
    using SafeMath for uint256;

    uint256 nonce;
    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public maxIndex;

    modifier creatorOnly(uint256 _id) {
        //require(creators[_id] == msg.sender);
        require(hasRole(bytes32(_id), msg.sender), "Not creator");
        _;
    }

    constructor (string memory uri_) ERC1155MixedFungible(uri_) {}

    // This function only creates the type.
    function create(
        string calldata _uri,
        bool _isNF)
    external returns (uint256 _type) {

        // Store the type in the upper 128 bits
        _type = (++nonce << 128);

        // Set a flag if this is an NFI.
        if (_isNF)
            _type = _type | TYPE_NF_BIT;

        // This will allow restricted access to creators.
        creators[_type] = msg.sender;
        _setupRole(bytes32(_type), msg.sender);

        console.log("Type %s", _type);

        // emit a Transfer event with Create semantic to help with discovery.
        emit TransferSingle(msg.sender, address(0x0), address(0x0), _type, 0);

        if (bytes(_uri).length > 0)
            emit URI(_uri, _type);
    }

    function mintNonFungible(uint256 _type, address[] calldata _to) external creatorOnly(_type) {

        // No need to check this is a nf type rather than an id since
        // creatorOnly() will only let a type pass through.
        require(isNonFungible(_type));

        // Index are 1-based.
        uint256 index = maxIndex[_type] + 1;
        maxIndex[_type] = _to.length.add(maxIndex[_type]);

        for (uint256 i = 0; i < _to.length; ++i) {
            address dst = _to[i];
            uint256 id = _type | index + i;

            nfOwners[id] = dst;

            console.log(id);
            console.log(dst);
            // You could use base-type id to store NF type _balances if you wish.
            // _balances[_type][dst] = quantity.add(_balances[_type][dst]);

            emit TransferSingle(msg.sender, address(0x0), dst, id, 1);

            if (dst != tx.origin) {
                _doSafeTransferAcceptanceCheck(msg.sender, msg.sender, dst, id, 1, '');
            }
        }
    }

    function mintFungible(uint256 _id, address[] calldata _to, uint256[] calldata _quantities) external creatorOnly(_id) {

        require(isFungible(_id));

        for (uint256 i = 0; i < _to.length; ++i) {

            address to = _to[i];
            uint256 quantity = _quantities[i];

            // Grant the items to the caller
            _balances[_id][to] = quantity.add(_balances[_id][to]);

            // Emit the Transfer/Mint event.
            // the 0x0 source address implies a mint
            // It will also provide the circulating supply info.
            emit TransferSingle(msg.sender, address(0x0), to, _id, quantity);

            if (to != tx.origin) {
                _doSafeTransferAcceptanceCheck(msg.sender, msg.sender, to, _id, quantity, '');
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerable, ERC1155MixedFungible) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}