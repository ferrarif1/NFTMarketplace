// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract OneRingNFT is ERC721, ERC721Enumerable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  string[] public tokenURIs;
  mapping(string => bool)public _tokenURIExists;
  mapping(uint => string)public _tokenIdToTokenURI;
  mapping(uint => string)public _tokenIdToCollectionName;
  mapping(string => address)private _collectionNameToCollectionOwner;

  constructor() ERC721("One Ring Collection", "ORC") {}

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function tokenURI(uint256 tokenId) public override view returns (string memory) {
    require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
    return _tokenIdToTokenURI[tokenId];
  }

  function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
     return super.tokenOfOwnerByIndex(owner, index);
  }

  function safeMint(string memory _tokenURI) public {
    require(!_tokenURIExists[_tokenURI], 'The token URI should be unique');
    tokenURIs.push(_tokenURI);    
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    _tokenIdToTokenURI[newItemId] = _tokenURI;
    _safeMint(msg.sender, newItemId);
    _tokenURIExists[_tokenURI] = true;
  }
  //NFT加入到Collection 
  //这种情况下 NFT可以更改为新的Collection
  function addTokenIdToCollection(uint tokenId, string memory collectionName) public{
    address collectionOwner = _collectionNameToCollectionOwner[collectionName];
    //需要Collection存在
    require(collectionOwner != address(0),'This collection does not exist !');
    //调用者为Collection Owner
    require(msg.sender == collectionOwner, 'msg.sender should be collection owner');
    //调用者同时还是NFT Owner
    require(msg.sender == super.ownerOf(tokenId), 'msg.sender should be NFT owner');
    _tokenIdToCollectionName[tokenId] = collectionName;
    if(collectionOwner == address(0)){
      _collectionNameToCollectionOwner[collectionName] = msg.sender;
    }
  }
  //注册新Collection
  function registerNewCollection(string memory collectionName)public{
    address collectionOwner = _collectionNameToCollectionOwner[collectionName];
    //要求Collection不存在
    require(collectionOwner == address(0), 'collection already exists');
    _collectionNameToCollectionOwner[collectionName] = msg.sender;
  }
  //查询Collection的Owner
  function ownerOfCollectionName(string memory collectionName) public view  returns(address){
    address collectionOwner = _collectionNameToCollectionOwner[collectionName];
    return collectionOwner;
  }

}