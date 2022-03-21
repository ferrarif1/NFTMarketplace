// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./oracle.sol";

contract OneRingNFT is ERC721, ERC721Enumerable, Ownable{
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  string[] public tokenURIs;
  address oracleAddr;
  mapping(string => bool)public _tokenURIExists;
  mapping(uint => string)public _tokenIdToTokenURI;
  mapping(uint => string)public _tokenIdToCollectionName;
  mapping(string => address)private _collectionNameToCollectionOwner;
  ////oracle 0 data
  mapping(string => uint256)public _tokenURLToNFT_ID_IN_Oracle;

  constructor() ERC721("One Ring Collection", "ORC") {}
 ////oracle 3 check result
  modifier tokenUrlPassed(string memory _tokenURI){ 
     require(oracleAddr != address(0),"please set oracle first!");
     NFTOracle oracle = NFTOracle(oracleAddr);
     uint256 NFTid = _tokenURLToNFT_ID_IN_Oracle[_tokenURI];
     bool result = false;
     result = oracle.checkNFTByID(NFTid);
     require(result == true, "oracle did not passed!");
     _;
  }
  //oracle 1 setup 后台调用
  function setOracleAddress(address oracleaddr)public onlyOwner{
     oracleAddr = oracleaddr;
  }
  //oracle 2 upload 后台调用
  function checkTokenURLBeforeMint(string memory tokenHash, string memory _tokenURI) public{
     require(oracleAddr != address(0),"please set oracle first!");
     NFTOracle oracle = NFTOracle(oracleAddr);
     uint256 NFT_ID_IN_Oracle = oracle.uploadNFT(tokenHash, _tokenURI);
     _tokenURLToNFT_ID_IN_Oracle[_tokenURI] = NFT_ID_IN_Oracle;
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
 

  function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
     return super.tokenOfOwnerByIndex(owner, index);
  }
  /*
  铸造NFT 
  @_tokenURI 传入ipfs地址作为tokenURL
  */
  function safeMint(string memory _tokenURI) public tokenUrlPassed(_tokenURI){
    require(!_tokenURIExists[_tokenURI], 'The token URI should be unique');
    tokenURIs.push(_tokenURI);    
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    _tokenIdToTokenURI[newItemId] = _tokenURI;
    _safeMint(msg.sender, newItemId);
    _tokenURIExists[_tokenURI] = true;
  }
  /*             NFT加入到Collection              */
  /*
  NFT加入到Collection 
  @tokenId NFT的id
  @collectionName 自定义collection名称
  需要先调用registerNewCollection（）注册一个新collection 再将NFT加入进去
  这种情况下 NFT可以更改为新的Collection
  */
  function addTokenIdToCollection(uint tokenId, string memory collectionName) public{
    address collectionOwner = _collectionNameToCollectionOwner[collectionName];
    //需要Collection已存在
    require(collectionOwner != address(0),'This collection does not exist !');
    //调用者为Collection Owner
    require(msg.sender == collectionOwner, 'msg.sender should be collection owner');
    //调用者同时还是NFT Owner
    require(msg.sender == super.ownerOf(tokenId), 'msg.sender should be NFT owner');
    //NFT绑定到collection
    _tokenIdToCollectionName[tokenId] = collectionName;
  }
  
  /*
  注册新Collection
  @collectionName 自定义collection名称
  */
  function registerNewCollection(string memory collectionName)public{
    address collectionOwner = _collectionNameToCollectionOwner[collectionName];
    //要求Collection不存在
    require(collectionOwner == address(0), 'collection already exists');
    _collectionNameToCollectionOwner[collectionName] = msg.sender;
  }
  
  /*
  查询Collection的Owner
  @collectionName 自定义collection名称
  @return collection的注册账号地址
  */
  function ownerOfCollectionName(string memory collectionName) public view  returns(address){
    address collectionOwner = _collectionNameToCollectionOwner[collectionName];
    return collectionOwner;
  }

}