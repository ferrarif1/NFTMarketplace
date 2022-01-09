// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SummerNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
contract SummerNFTMarketplace is Ownable {
  Counters.Counter private _offerIds;
  /*
  England -> increase price    (* Default *) 
  Netherlands -> decrease price
  Simple -> Fixed price

  英格兰拍卖：nft owner设置初始起拍价格，竞拍者逐步提高价格发起offer，价高者得 只能通过offer与接受offer达成，完成交易主动权在owner
  荷兰拍卖： nft owner设置初始价格，竞拍者给出满足该价格的offer或者价格更低的offer，nft owner可以主动降价，直到有双方都满意的价格出现 只能通过offer与接受offer达成，完成交易主动权在owner
  普通定价模式：nft owner设置初始价格，出价者可任意给offer，或者直接通过simpleBuyNFT()按当前最高标价购买 可以通过offer或直接购买达成，完成交易主动权在双方
  */
  enum AuctionsType {England, Netherlands, Simple}

  mapping (uint => _Offer[]) private tokenIdToOffers;
  mapping (uint => uint) private tokenIdToBestPrice;
  mapping (address => uint) private userFunds;
  mapping (address => AuctionsType) private tokenIdToAuctionsType;
  mapping (uint => uint) private OfferIdToTokenId;
  
  SummerNFT summerNFT;
  
  struct _Offer {
    uint offerId;
    uint id;
    address user;
    uint price;
    bool fulfilled;
    bool cancelled;
  }


  event Offer(
    uint offerId,
    uint id,
    address user,
    uint price,
    bool fulfilled,
    bool cancelled
  );

  event OfferFilled(uint offerId, uint id, address newOwner);
  event OfferCancelled(uint offerId, uint id, address owner);
  event ClaimFunds(address user, uint amount);

  constructor(address _summerNFT) {
    summerNFT = SummerNFT(_summerNFT);
  }

  modifier onlyOwnerOf(uint _NFTid){
      address ownerOfNFT =  summerNFT.ownerOf(_NFTid);
      require(msg.sender == ownerOfNFT);
      _;
  }

 
/*
  add to sell list and set start price, choose AuctionsType
  withdraw NFT from sell list
*/
  function addNFTToSellList(uint _id, uint _price, uint _typeNum) public onlyOwnerOf(_id){
     summerNFT.transferFrom(msg.sender, address(this), _id); 
     if(_typeNum == 0){
        tokenIdToAuctionsType[_id] = AuctionsType.England;
     }else if(_typeNum == 1){
       tokenIdToAuctionsType[_id] = AuctionsType.Netherlands;
     }else{
       tokenIdToAuctionsType[_id] = AuctionsType.Simple;
     }
     tokenIdToBestPrice[_id] = _price;
  }

  function withdrawNFTFromSellList(uint _id) public onlyOwnerOf(_id){
    summerNFT.transferFrom(address(this), msg.sender, _id);
  }
/*
  decrease price for AuctionsType.Netherlands
*/
  function decreasePriceForNetherlandsAuctionsType(uint _id,  uint _price) public onlyOwnerOf(_id){
     AuctionsType _auctionsType = tokenIdToAuctionsType[_id];
     require(_auctionsType == AuctionsType.Netherlands);
     uint  _currentBestPrice = tokenIdToBestPrice[_id];
     require(_price <= _currentBestPrice, 'The new price should be lesser than current best price given by owner of nft');
     tokenIdToBestPrice[_id] = _price;
  }
  /*
   change price for AuctionsType.Simple
  */
function changePriceForSimpleAuctionsType(uint _id,  uint _price) public onlyOwnerOf(_id){
     AuctionsType _auctionsType = tokenIdToAuctionsType[_id];
     require(_auctionsType == AuctionsType.Simple);
     uint  _currentBestPrice = tokenIdToBestPrice[_id];
     tokenIdToBestPrice[_id] = _price;
  }
/*
  give offer 1, send eth to contract
*/
  function makeOffer(uint _id, uint _price) public payable{
    //0.check amount
    require(msg.value == _price, 'The ETH amount should match with the offer Price');
    //1.if new price should be the best price
    uint  _currentBestPrice = tokenIdToBestPrice[_id];
    AuctionsType _auctionsType = tokenIdToAuctionsType[_id];
    if(_auctionsType == AuctionsType.England){
      require(_price > _currentBestPrice, 'The new price should be largger than current best price');
      //2.set new best price
      tokenIdToBestPrice[_id] = _price;
    }else if(_auctionsType == AuctionsType.Netherlands){
      require(_price <= _currentBestPrice, 'The new price should be lesser than/equal to current best price given by owner of nft');
    }
    //3.add new offer to offerlist
      _Offer[] storage offersOfId = tokenIdToOffers[_id];
      uint offerCount = offersOfId.length + 1;
      //_tokenIds自增，保证每个NFT的id唯一
      _offerIds.increment();
      //指定nft的id
      uint256 newOfferId = _offerIds.current();
      offersOfId[offersOfId.length] = _Offer(newOfferId, _id, msg.sender, _price, false, false);
      tokenIdToOffers[_id] = offersOfId;
      OfferIdToTokenId[newOfferId] = _id;
      //4.emit event
      emit Offer(newOfferId, _id, msg.sender, _price, false, false);
    
  }

/*
  give offer 2, pay with funds
*/
  function makeOfferWithUserFunds(uint _id, uint _price) public{
    //0.check if balance is enough, if so, update balance
    require(userFunds[msg.sender] >= _price, 'The ETH amount should match with the offer Price');
    uint newbalance = userFunds[msg.sender] - _price; 
    userFunds[msg.sender] = newbalance; 
    //1.if new price is the best price
    uint  _currentBestPrice = tokenIdToBestPrice[_id];
    AuctionsType _auctionsType = tokenIdToAuctionsType[_id];
    if(_auctionsType == AuctionsType.England){
      require(_price > _currentBestPrice, 'The new price should be largger than current best price');
       //2.set new best price
      tokenIdToBestPrice[_id] = _price;
    }else if(_auctionsType == AuctionsType.Netherlands){
      require(_price <= _currentBestPrice, 'The new price should be lesser/equal to current best price given by owner of nft');
    }
    //3.add new offer to offerlist
    _Offer[] storage offersOfId = tokenIdToOffers[_id];
    uint offerCount = offersOfId.length + 1;
    //_tokenIds自增，保证每个NFT的id唯一
    _offerIds.increment();
    //指定nft的id
    uint256 newOfferId = _offerIds.current();
    offersOfId[offersOfId.length] = _Offer(newOfferId, _id, msg.sender, _price, false, false);
    tokenIdToOffers[_id] = offersOfId;
    OfferIdToTokenId[newOfferId] = _id;
    //4.emit event
    emit Offer(newOfferId, _id, msg.sender, _price, false, false);
  }

/*
fill Offer by nft owner
accept one offer and reject others
*/
  function fillOfferByOwner(uint _offerId, uint _tokenId) public payable onlyOwnerOf(_tokenId){
    _Offer[] memory offersOfId = tokenIdToOffers[_tokenId];
    require(offersOfId.length > 0, 'No Offer exist');
    _Offer memory currentOffer = _Offer(0, 0, msg.sender, 0, false, false);
    for(uint index = 0; index < offersOfId.length; index++){
      _Offer memory offerIndex = offersOfId[index];
      if(offerIndex.offerId == _offerId){
        currentOffer = offerIndex;
      }
    }
    require(currentOffer.offerId == _offerId, 'The offer must exist');
    require(!currentOffer.fulfilled, 'An offer cannot be fulfilled twice');
    require(!currentOffer.cancelled, 'A cancelled offer cannot be fulfilled');
    require(msg.value == currentOffer.price, 'The ETH amount should match with the NFT Price');
    summerNFT.transferFrom(address(this), msg.sender, currentOffer.id);
    currentOffer.fulfilled = true;
    userFunds[currentOffer.user] += msg.value;
    emit OfferFilled(_offerId, currentOffer.id, msg.sender);
    //cancel other offers , refund or update userFunds
    for(uint index = 0; index < offersOfId.length; index++){
      _Offer memory offerIndex = offersOfId[index];
      if(offerIndex.offerId != _offerId){
        offerIndex.cancelled = true;
        userFunds[offerIndex.user] = offerIndex.price;
      }
    }
  }

/*
cancel Offer
reject the best offer and cancel other offers
only cancel, still on sale(NFT hold by contract)
*/
  function cancelOffer(uint _offerId, uint _tokenId) public  onlyOwnerOf(_tokenId){
    _Offer[] memory offersOfId = tokenIdToOffers[_tokenId];
    require(offersOfId.length > 0, 'No Offer exist');
    _Offer memory currentOffer = _Offer(0, 0, msg.sender, 0, false, false);
    for(uint index = 0; index < offersOfId.length; index++){
      _Offer memory offerIndex = offersOfId[index];
      if(offerIndex.offerId == _offerId){
        currentOffer = offerIndex;
      }
    }
    require(currentOffer.offerId == _offerId, 'The offer must exist');
    require(currentOffer.fulfilled == false, 'A fulfilled offer cannot be cancelled');
    require(currentOffer.cancelled == false, 'An offer cannot be cancelled twice');
     //cancel every offers , refund or update userFunds
    for(uint index = 0; index < offersOfId.length; index++){
      _Offer memory offerIndex = offersOfId[index];
      offerIndex.cancelled = true;
      userFunds[offerIndex.user] = offerIndex.price;
    }
    emit OfferCancelled(_offerId, currentOffer.id, msg.sender);
  }

/*
simple buy NFT without offer
*/
function simpleBuyNFT(uint _tokenId) public payable{
    //0.only for AuctionsType.Simple
    AuctionsType _auctionsType = tokenIdToAuctionsType[_id];
    require(_auctionsType == AuctionsType.Simple);
    //1.if new price match the best price
    uint  _currentBestPrice = tokenIdToBestPrice[_id];
    require(msg.value == _currentBestPrice);
    //2.transfer nft
    summerNFT.transferFrom(address(this), msg.sender, _tokenId);
    //3.update userFunds for nft owner
    address ownerOfNFT =  summerNFT.ownerOf(_NFTid);
    userFunds[ownerOfNFT] += msg.value;
    //4.cancel other offers , refund or update userFunds
    _Offer[] memory offersOfId = tokenIdToOffers[_tokenId];
    for(uint index = 0; index < offersOfId.length; index++){
      _Offer memory offerIndex = offersOfId[index];
      offerIndex.cancelled = true;
      userFunds[offerIndex.user] = offerIndex.price;
    }
  }
/*
cancel Offer and withdraw NFT from contract
reject the best price means cancel all the offer
*/
  function cancelOfferAndWithdrawFromSellList(uint _offerId, uint _tokenId) public  onlyOwnerOf(_tokenId){
    _Offer[] memory offersOfId = tokenIdToOffers[_tokenId];
    require(offersOfId.length > 0, 'No Offer exist');
    _Offer memory currentOffer = _Offer(0, 0, msg.sender, 0, false, false);
    for(uint index = 0; index < offersOfId.length; index++){
      _Offer memory offerIndex = offersOfId[index];
      if(offerIndex.offerId == _offerId){
        currentOffer = offerIndex;
      }
    }
    require(currentOffer.offerId == _offerId, 'The offer must exist');
    require(currentOffer.fulfilled == false, 'A fulfilled offer cannot be cancelled');
    require(currentOffer.cancelled == false, 'An offer cannot be cancelled twice');
     //cancel every offers , refund or update userFunds
    for(uint index = 0; index < offersOfId.length; index++){
      _Offer memory offerIndex = offersOfId[index];
      offerIndex.cancelled = true;
      userFunds[offerIndex.user] = offerIndex.price;
    }
    summerNFT.transferFrom(address(this), msg.sender, _tokenId);
    emit OfferCancelled(_offerId, _tokenId, msg.sender);
  }
/*
claim Funds
*/
  function claimFunds() public {
    require(userFunds[msg.sender] > 0, 'This user has no funds to be claimed');
    payable(msg.sender).transfer(userFunds[msg.sender]);
    emit ClaimFunds(msg.sender, userFunds[msg.sender]);
    userFunds[msg.sender] = 0;    
  }

  /********************************** 查询 **********************************/
/*
request owner of nftid
*/
 function ownerOfNFTId(uint _NFTid)public view returns(address memory){
    address ownerOfNFT =  summerNFT.ownerOf(_NFTid);
    return ownerOfNFT;
  }
/*
request balance of owner
*/
 function balanceOf(address _owner) public view returns (uint256) {
    uint256 balance =  summerNFT.balanceOf(_owner);
    return ownerOfNFT;
 }
/*
request nftid of owner at index i
*/
function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256) {
    uint256 tokenid =  summerNFT.tokenOfOwnerByIndex(_owner, _index);
    return tokenid;
}
/*
  request tokenURI of nftid
*/
 function tokenURIOfNFTId(uint _NFTid)public view returns(string memory){
    address tokenURI =  summerNFT.tokenURI(tokenId);
    return tokenURI;
 }


/*
request best price of nftid
*/
  function bestPriceOfNFTId(uint _NFTid)public view returns(uint256 memory){
    uint  _currentBestPrice = tokenIdToBestPrice[_id];
    return _currentBestPrice;
  }

/*
request all offers for nftid
*/
  function offersOfNFTId(uint _NFTid)public view returns(_Offer[] memory){
    _Offer[] memory offersOfId = tokenIdToOffers[_tokenId];
    return offersOfId;
  }
/*
  request offer detail of offer id
*/
  function offerDataOfOfferId(uint _Offerid)public view returns(_Offer memory){
    uint _tokenId = OfferIdToTokenId[_Offerid];
    _Offer[] memory offersOfId = tokenIdToOffers[_tokenId];
    require(offersOfId > 0,"No offers");
    for(uint index = 0; index < offersOfId.length; index++){
      _Offer memory offerIndex = offersOfId[index];
      if(offerIndex.offerId == _Offerid){
        return offerIndex;
      }
    }
    return _Offer(-1, -1, address(0), 0, false, false);
  }

  // Fallback: reverts if Ether is sent to this smart-contract by mistake
  fallback () external {
    revert();
  }
}
