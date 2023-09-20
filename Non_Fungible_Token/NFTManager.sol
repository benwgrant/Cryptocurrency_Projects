// SPDX-License-Identifier: GPL-3.0-or-later
// Ben Grant (bwg9sbe)

pragma solidity ^0.8.16;

import "./INFTManager.sol";
// import "./IERC165.sol";
import "./ERC721.sol";
// import "./IERC721Receiver.sol";
// import "./IERC721Metadata.sol";

contract NFTManager is INFTManager, ERC721 {
    mapping(string => uint256) private _URIs;
    mapping(uint256 => string) private _tokenURIs;

    uint private _count;
    string private _name;
    string private _symbol;

    constructor (string memory name, string memory symbol) ERC721("NFTManager", "NFTM") {
        _name = name;
        _symbol = symbol;
        _count = 0;
    }

    // Override _base_uri function from erc721
    function _baseURI() internal pure override returns (string memory) {
        return "https://collab.its.virginia.edu/access/content/group/e9ad2fbb-faca-414b-9df1-6f9019e765e9/ipfs/";
    }


    // This creates a NFT for `_to` with the pased file name `_uri`.
    // that `_uri` is just the filename itself -- the prefix is set via
    // overriding _baseURI()
    function mintWithURI(address _to, string memory _uri) public override returns (uint) {
        require(_URIs[_uri] == 0, "The URI has already been used");
        _count++;

        _mint(_to, _count);
        _tokenURIs[_count] = _uri;
        _URIs[_uri] = _count;
        
        return _count;
    }

    function mintWithURI(string memory _uri) public override returns (uint) {
        return mintWithURI(msg.sender, _uri);
    }

    function count() external view override returns (uint) {
        return _count;
    }

    // supports interface with IERC721, IERC721Metadata, IERC165, and INFTManager
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId || interfaceId == type(IERC165).interfaceId || interfaceId == type(INFTManager).interfaceId;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, IERC721Metadata) returns (string memory) {
        // Revert if it's an invalid token ID
        require(_exists(tokenId), "Invalid Token ID");
        return string.concat(_baseURI(), _tokenURIs[tokenId]);
    }
}