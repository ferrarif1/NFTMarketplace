// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SummerNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SummerNFTMarketplace is Ownable {
  /*
  England -> increase price    (* Default *)
  Netherlands -> decrease price
  Simple -> Fixed price
  */
  enum AuctionsType {England, Netherlands, Simple}

  mapping (uint => _Offer[]) public tokenIdToOffers;
  mapping (uint => uint) public tokenIdToBestPrice;
  mapping (address => uint) public userFunds;
  mapping (address => AuctionsType) public tokenIdToAuctionsType;
  
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
  give offer, send eth to contract
  英格兰拍卖：nft owner设置初始起拍价格，竞拍者逐步提高价格发起offer，价高者得
  荷兰拍卖： nft owner设置初始价格，竞拍者给出满足该价格的offer或者价格更低的offer，nft owner可以主动降价，直到有双方都满意的价格出现
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
      uint offerCount = offersOfId.length;
      offerCount ++;
      offersOfId[offersOfId.length] = _Offer(offerCount, _id, msg.sender, _price, false, false);
      tokenIdToOffers[_id] = offersOfId;
      //4.emit event
      emit Offer(offerCount, _id, msg.sender, _price, false, false);
    
  }

/*
  give offer, pay with funds
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
    uint offerCount = offersOfId.length;
    offerCount ++;
    offersOfId[offersOfId.length] = _Offer(offerCount, _id, msg.sender, _price, false, false);
    tokenIdToOffers[_id] = offersOfId;
    //4.emit event
    emit Offer(offerCount, _id, msg.sender, _price, false, false);
  }

/*
fill Offer
accept one offer and reject others
*/
  function fillOffer(uint _offerId, uint _tokenId) public payable{
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

  // Fallback: reverts if Ether is sent to this smart-contract by mistake
  fallback () external {
    revert();
  }
}