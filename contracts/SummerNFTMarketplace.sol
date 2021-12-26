// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SummerNFT.sol";

contract SummerNFTMarketplace {
  
  mapping (uint => _Offer[]) public tokenIdToOffers;
  mapping (uint => _bestPrice) public tokenIdToBestPrice;
  mapping (address => uint) public userFunds;
  /*
  England -> increase price    (* Default *)
  Netherlands -> decrease price
  Simple -> Fixed price
  */
  enum AuctionsType {England, Netherlands, Simple}
  AuctionsType _auctionsType = England;

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
      require(msg.sender == summerNFT.ownerOf[_NFTid]);
      _;
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
    uint memory _currentBestPrice = tokenIdToBestPrice[_id];
    if(_auctionsType == England){
      require(_price > _currentBestPrice);
    }else if(_auctionsType == Netherlands){//if Netherlands, Offers are made by owner
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
  function fillOffer(uint _offerId) public payable {
    _Offer storage _offer = tokenIdToOffers[_offerId];
    require(_offer.offerId == _offerId, 'The offer must exist');
    require(_offer.user != msg.sender, 'The owner of the offer cannot fill it');
    require(!_offer.fulfilled, 'An offer cannot be fulfilled twice');
    require(!_offer.cancelled, 'A cancelled offer cannot be fulfilled');
    require(msg.value == _offer.price, 'The ETH amount should match with the NFT Price');
    summerNFT.transferFrom(address(this), msg.sender, _offer.id);
    _offer.fulfilled = true;
    userFunds[_offer.user] += msg.value;
    emit OfferFilled(_offerId, _offer.id, msg.sender);
  }
/*
cancel Offer
*/
  function cancelOffer(uint _offerId) public {
    _Offer storage _offer = tokenIdToOffers[_offerId];
    require(_offer.offerId == _offerId, 'The offer must exist');
    require(_offer.user == msg.sender, 'The offer can only be canceled by the owner');
    require(_offer.fulfilled == false, 'A fulfilled offer cannot be cancelled');
    require(_offer.cancelled == false, 'An offer cannot be cancelled twice');
    summerNFT.transferFrom(address(this), msg.sender, _offer.id);
    _offer.cancelled = true;
    emit OfferCancelled(_offerId, _offer.id, msg.sender);
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