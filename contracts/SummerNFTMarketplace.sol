// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SummerNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SummerNFTMarketplace is Ownable {
  
  mapping (uint => _Offer[]) public tokenIdToOffers;
  mapping (uint => uint) public tokenIdToBestPrice;
  mapping (address => uint) public userFunds;
  /*
  England -> increase price    (* Default *)
  Netherlands -> decrease price
  Simple -> Fixed price
  */
  enum AuctionsType {England, Netherlands, Simple}
  AuctionsType _auctionsType = AuctionsType.England;

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

  function setAuctionsType(uint _typeNum) public onlyOwner{
     if(_typeNum == 0){
        _auctionsType = AuctionsType.England;
     }else if(_typeNum == 1){
       _auctionsType = AuctionsType.Netherlands;
     }else{
       _auctionsType = AuctionsType.Simple;
     }
  }
/*
  add to sell list and set start price
*/
  function addNFTToSellList(uint _id, uint _price) public onlyOwnerOf(_id){
     summerNFT.transferFrom(msg.sender, address(this), _id); 
     tokenIdToBestPrice[_id] = _price;
  }
/*
  give offer
*/
  function makeOffer(uint _id, uint _price) public {
    //1.if new price is the best price
    uint  _currentBestPrice = tokenIdToBestPrice[_id];
    if(_auctionsType == AuctionsType.England){
      require(_price > _currentBestPrice);
    }else if(_auctionsType == AuctionsType.Netherlands){//if Netherlands, Offers are made by owner
      require(_price < _currentBestPrice);
    }
    //2.set new best price
    tokenIdToBestPrice[_id] = _price;
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
  }
/*
cancel Offer
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
    summerNFT.transferFrom(address(this), msg.sender, currentOffer.id);
    currentOffer.cancelled = true;
    emit OfferCancelled(_offerId, currentOffer.id, msg.sender);
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