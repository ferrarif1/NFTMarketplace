// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OneRingNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
contract OneRingNFTMarketplace is Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _offerIds;
  /*
  England -> increase price    (* Default *) 
  Netherlands -> decrease price
  Simple -> Fixed price

  英格兰拍卖 0：nft owner设置初始起拍价格，竞拍者逐步提高价格发起offer，价高者得 只能通过offer与接受offer达成，完成交易主动权在owner
  荷兰拍卖 1： nft owner设置初始价格，竞拍者给出满足该价格的offer或者价格更低的offer，nft owner可以主动降价，直到有双方都满意的价格出现 只能通过offer与接受offer达成，完成交易主动权在owner
  普通定价模式 other num：nft owner设置初始价格，出价者给offer需要满足比当前最佳offer金额更高，或者直接通过simpleBuyNFT()按startPrice标价购买 可以通过offer或直接购买达成，完成交易主动权在双方
  */
  enum AuctionsType {England, Netherlands, Simple}
  enum OfferStatus {available, fulfilled, cancelled}
  
  mapping (uint => _Offer)private allOffers;//全部offer
  mapping (uint => uint[]) private tokenIdToOfferIds;//nft对应的全部offer的id
  mapping (uint => uint) private tokenIdToBestOfferId;//最佳Offer id
  mapping (uint => uint) private tokenIdToStartPrice;//nft owner设置的初始价格
  mapping (address => uint) private userFunds;//用户在合约的存款余额
  mapping (uint => AuctionsType) private tokenIdToAuctionsType;//nft的拍卖模式
  mapping (uint => address)private tokenIdToOriginalAddress;//记录addtoselllist后的nft的原所有者

  OneRingNFT oneRingNFT;
  
  struct _Offer {
    uint offerId;  //offer id
    uint tokenId;       //NFT id
    address user;  //offer given by whom
    uint price;    
    OfferStatus offerstatus;
  }

  event Offer(
    uint offerId,
    uint tokenId,
    address user,
    uint price,
    OfferStatus offerstatus
  );

  event OfferFilled(uint offerId, uint tokenId, address newOwner);
  event OfferCancelled(uint offerId, uint tokenId, address owner);
  event ClaimFunds(address user, uint amount);

  constructor(address _oneRingNFT) payable{
    oneRingNFT = OneRingNFT(_oneRingNFT);
  }

  modifier onlyOwnerOf(uint _tokenId){
      address ownerOfNFT =  oneRingNFT.ownerOf(_tokenId);
      require(msg.sender == ownerOfNFT);
      _;
  }
  //NFT在addNFTToSellList后所有者变更为合约，这里tokenIdToOriginalAddress记录NFT的原所有者
  modifier onlyOriginalOwnerOf(uint _tokenId){
      address originalOwnerOfNFT =  tokenIdToOriginalAddress[_tokenId];
      require(msg.sender == originalOwnerOfNFT);
      _;
  }
 
/*
  add to sell list and set start price, choose AuctionsType
  withdraw NFT from sell list
  将NFT加入销售列表：NFT从个人地址转入合约地址，设置初始价格，拍卖类型
*/
  function addNFTToSellList(uint _tokenId, uint _price, uint _typeNum) public onlyOwnerOf(_tokenId){
     oneRingNFT.transferFrom(msg.sender, address(this), _tokenId); 
     tokenIdToOriginalAddress[_tokenId] = msg.sender;
     if(_typeNum == 0){
       tokenIdToAuctionsType[_tokenId] = AuctionsType.England;
     }else if(_typeNum == 1){
       tokenIdToAuctionsType[_tokenId] = AuctionsType.Netherlands;
     }else{
       tokenIdToAuctionsType[_tokenId] = AuctionsType.Simple;
     }
     tokenIdToStartPrice[_tokenId] = _price;
  }
// /*
//   取消销售，从合约取回NFT
//   没有offer的情况
// */
//   function withdrawNFTFromSellList(uint _tokenId) public onlyOriginalOwnerOf(_tokenId){
//     oneRingNFT.transferFrom(address(this), msg.sender, _tokenId);
//   }
/*
  decrease price for AuctionsType.Netherlands
  荷兰拍卖模式下 NFT拥有者主动降低价格
*/
  function decreasePriceForNetherlandsAuctionsType(uint _tokenId,  uint _price) public onlyOriginalOwnerOf(_tokenId){
     AuctionsType _auctionsType = tokenIdToAuctionsType[_tokenId];
     require(_auctionsType == AuctionsType.Netherlands,"AuctionsType should be Netherlands");
     uint  _currentStartPrice = tokenIdToStartPrice[_tokenId];
     require(_price <= _currentStartPrice, 'The new price should be lesser than current best price given by owner of nft');
     tokenIdToStartPrice[_tokenId] = _price;
  }
  /*
   change price for AuctionsType.Simple
   简单拍卖模式下，NFT拥有者修改价格
  */
function changePriceForSimpleAuctionsType(uint _tokenId,  uint _price) public onlyOriginalOwnerOf(_tokenId){
     AuctionsType _auctionsType = tokenIdToAuctionsType[_tokenId];
     require(_auctionsType == AuctionsType.Simple);
     tokenIdToStartPrice[_tokenId] = _price;
  }
/*
  give offer 1, send eth to contract
  使用ether支付，给出竞拍某NFT的Offer
  *** 新offer必为bestOffer ***
*/
  function makeOffer(uint _tokenId, uint _price) public payable{
    //0.check amount
    require(msg.value >= _price, 'The ETH amount should match with the offer Price');
    //1.if new price should be the best price
    //如果没有offer，当前最佳价格为0
    uint  _currentBestPrice = 0;
    uint currentBestOfferId = tokenIdToBestOfferId[_tokenId];
    if(currentBestOfferId > 0){//如果有offer，更新为最佳offer价格
       _Offer memory currentBestOffer = allOffers[currentBestOfferId];
       _currentBestPrice = currentBestOffer.price;
    }
    uint startPrice = tokenIdToStartPrice[_tokenId];
    AuctionsType _auctionsType = tokenIdToAuctionsType[_tokenId];
    if(_auctionsType == AuctionsType.England){
      //2.set new best price 英格兰模式下，新Offer必须满足更高的金额, 且高于初始价格startPrice
      require(_price > _currentBestPrice, 'The new price should be largger than current best offer price for AuctionsType.England');
      require(_price > startPrice, 'The new price should be largger than start price for AuctionsType.England');
    }else if(_auctionsType == AuctionsType.Netherlands){
      //2.荷兰模式降价拍卖，给出Offer金额小于等于startPrice, 大于等于当前最高Offer金额
      require(_price > _currentBestPrice, 'The new price should be lesser than/equal to current best offer price for AuctionsType.Netherlands');
      require(_price <= startPrice, 'The new price should be lesser/equal than start price for AuctionsType.Netherlands');
    }else{
      //2.普通模式，新Offer也必须满足更高的金额，但不高出原价startPrice，若按startPrice购买，直接调用simpleBuyNFT()
      require(_price > _currentBestPrice, 'The new price should be largger than current best offer price for AuctionsType.Simple');
      require(_price < startPrice, 'The new price should be lesser than start price for AuctionsType.Simple');
    }
    //3.add new offer to offerlist
    uint[] storage offerIdsOfId = tokenIdToOfferIds[_tokenId];
    _offerIds.increment();//_offerIds从1开始递增
    uint256 newOfferId = _offerIds.current();
    //更新全部Offer列表
    _Offer memory newOffer = _Offer(newOfferId, _tokenId, msg.sender, _price, OfferStatus.available);
    allOffers[newOfferId] = newOffer;
    //更新nft对应的全部offer的id
    offerIdsOfId.push(newOfferId);
    tokenIdToOfferIds[_tokenId] = offerIdsOfId;
    //更新最佳Offer id
    tokenIdToBestOfferId[_tokenId] = newOfferId;
    
    //4.emit event
    emit Offer(newOfferId, _tokenId, msg.sender, _price, OfferStatus.available);
  }

/*
  give offer 2, pay with funds and eth
  组合支付使用用户存在合约的余额+ether支付，给出竞拍某NFT的Offer
  *** 新offer必为bestOffer ***
*/
  function makeOfferWithUserFundsAndEther(uint _tokenId, uint _price) public payable{
    //0.check if balance is enough
    require(userFunds[msg.sender] + msg.value >= _price, 'The ETH amount should match with the offer Price');
    //1.if new price is the best price
    //如果没有offer，当前最佳价格为0
    uint  _currentBestPrice = 0;
    uint currentBestOfferId = tokenIdToBestOfferId[_tokenId];
    if(currentBestOfferId > 0){//如果有offer，更新为最佳offer价格
       _Offer memory currentBestOffer = allOffers[currentBestOfferId];
       _currentBestPrice = currentBestOffer.price;
    }
    uint startPrice = tokenIdToStartPrice[_tokenId];
    AuctionsType _auctionsType = tokenIdToAuctionsType[_tokenId];
    if(_auctionsType == AuctionsType.England){
      //2.set new best price 英格兰模式下，新Offer必须满足更高的金额, 且高于初始价格startPrice
      require(_price > _currentBestPrice, 'The new price should be largger than current best offer price for AuctionsType.England');
      require(_price > startPrice, 'The new price should be largger than start price for AuctionsType.England');
    }else if(_auctionsType == AuctionsType.Netherlands){
      //2.荷兰模式降价拍卖，给出Offer金额小于等于startPrice, 大于等于当前最高Offer金额
      require(_price > _currentBestPrice, 'The new price should be lesser than/equal to current best offer price for AuctionsType.Netherlands');
      require(_price <= startPrice, 'The new price should be lesser/equal than start price for AuctionsType.Netherlands');
    }else{
      //2.普通模式，新Offer也必须满足更高的金额，但不高出原价startPrice，若按startPrice购买，直接调用simpleBuyNFT()
      require(_price > _currentBestPrice, 'The new price should be largger than current best offer price for AuctionsType.Simple');
      require(_price < startPrice, 'The new price should be lesser than start price for AuctionsType.Simple');
    }
    //3.update balance 如果条件都满足，则更新余额，扣款，这里如果余额充足，msg.value可以为0，优先扣除msg.value金额
    uint newbalance = userFunds[msg.sender] + msg.value - _price; 
    userFunds[msg.sender] = newbalance; 
    //4.add new offer to offerlist
    uint[] storage offerIdsOfId = tokenIdToOfferIds[_tokenId];
    _offerIds.increment();//_offerIds从1开始递增
    uint256 newOfferId = _offerIds.current();
    //更新全部Offer列表
    _Offer memory newOffer = _Offer(newOfferId, _tokenId, msg.sender, _price, OfferStatus.available);
    allOffers[newOfferId] = newOffer;
    //更新nft对应的全部offer的id
    offerIdsOfId.push(newOfferId);
    tokenIdToOfferIds[_tokenId] = offerIdsOfId;
    //更新最佳Offer id
    tokenIdToBestOfferId[_tokenId] = newOfferId;
    //4.emit event
    emit Offer(newOfferId, _tokenId, msg.sender, _price, OfferStatus.available);
  }

/*
fill Offer by nft owner
accept one offer and reject others
NFT拥有者接受offer
NFT由合约转给offer发起者，取消其他offer，相应用户余额增加
*/
  function fillOfferByNFTOwner(uint _offerId, uint _tokenId) public onlyOriginalOwnerOf(_tokenId){
    //找到_offerId对应的offer
    _Offer storage currentOffer = allOffers[_offerId];
    require(currentOffer.offerId == _offerId, 'The offer must exist');
    require(currentOffer.offerstatus == OfferStatus.available, 'Offer status should be available');
    //NFT转账给offer的发起人
    oneRingNFT.transferFrom(address(this), currentOffer.user, currentOffer.tokenId);
    //offer状态改为满足
    currentOffer.offerstatus = OfferStatus.fulfilled;
    //NFT原拥有者的合约存款余额增加
    address originalOwnerOfNFT = tokenIdToOriginalAddress[_tokenId];
    userFunds[originalOwnerOfNFT] += currentOffer.price;
    //cancel other offers , refund or update userFunds 取消其他offer，相应发起人的合约存款余额增加
    uint[] memory offerIdsOfTokenId = tokenIdToOfferIds[_tokenId];
    for(uint index = 0; index < offerIdsOfTokenId.length; index++){
      uint offerIdOfIndex = offerIdsOfTokenId[index];
      _Offer memory offerIndex = allOffers[offerIdOfIndex];
      if(offerIndex.offerId != _offerId){
        require(offerIndex.offerstatus == OfferStatus.available, 'Offer status should be available');
        offerIndex.offerstatus = OfferStatus.cancelled;
        userFunds[offerIndex.user] += offerIndex.price;
        emit OfferCancelled(offerIndex.offerId, offerIndex.tokenId, offerIndex.user);
      }
    }
    //NFT原拥有者置为0地址
    tokenIdToOriginalAddress[_tokenId] = address(0);
    emit OfferFilled(_offerId, currentOffer.tokenId, currentOffer.user);
  }

/*
reject all offers
only cancel, still on sale(NFT hold by contract)
取消所有offer
*/
  function rejectAllOffers(uint _tokenId) public  onlyOriginalOwnerOf(_tokenId){
    //cancel every offers , refund or update userFunds 取消全部offer，相应发起人的合约存款余额增加
    uint[] memory offerIdsOfTokenId = tokenIdToOfferIds[_tokenId];
    for(uint index = 0; index < offerIdsOfTokenId.length; index++){
      uint offerIdOfIndex = offerIdsOfTokenId[index];
      _Offer memory offerIndex = allOffers[offerIdOfIndex];
      require(offerIndex.offerstatus == OfferStatus.available, 'Offer status should be available');
      offerIndex.offerstatus = OfferStatus.cancelled;
      userFunds[offerIndex.user] += offerIndex.price;
      emit OfferCancelled(offerIndex.offerId, offerIndex.tokenId, offerIndex.user);
    }
  }
/*
cancel one's own Offer
撤销自己给出的offer
*/
  function cancelOwnOffer(uint _offerId)public{
    _Offer storage currentOffer = allOffers[_offerId];
    require(msg.sender == currentOffer.user, 'msg.sender should be owner of this offer');
    require(currentOffer.offerId == _offerId, 'The offer must exist');
    require(currentOffer.offerstatus == OfferStatus.available, 'Offer status should be available');
    currentOffer.offerstatus = OfferStatus.cancelled;
    userFunds[currentOffer.user] += currentOffer.price;
    emit OfferCancelled(_offerId, currentOffer.tokenId, msg.sender);
  }

/*
simple buy NFT without offer
AuctionsType.Simple模式下直接按标价购买NFT
*/
function simpleBuyNFT(uint _tokenId) public payable{
    //0.only for AuctionsType.Simple
    AuctionsType _auctionsType = tokenIdToAuctionsType[_tokenId];
    require(_auctionsType == AuctionsType.Simple);
    //1.if new price match the start price
    uint  startPrice = tokenIdToStartPrice[_tokenId];
    require(msg.value >= startPrice);
    //2.update userFunds for nft owner
    address originalOwnerOfNFT = tokenIdToOriginalAddress[_tokenId];
    userFunds[originalOwnerOfNFT] += msg.value;
    //3.transfer nft
    oneRingNFT.transferFrom(address(this), msg.sender, _tokenId);
    //4.cancel all other offers , refund or update userFunds 取消所有offer
    uint[] memory offerIdsOfTokenId = tokenIdToOfferIds[_tokenId];
    for(uint index = 0; index < offerIdsOfTokenId.length; index++){
      uint offerIdOfIndex = offerIdsOfTokenId[index];
      _Offer memory offerIndex = allOffers[offerIdOfIndex];
      require(offerIndex.offerstatus == OfferStatus.available, 'Offer status should be available');
      offerIndex.offerstatus = OfferStatus.cancelled;
      userFunds[offerIndex.user] += offerIndex.price;
      emit OfferCancelled(offerIndex.offerId, offerIndex.tokenId, offerIndex.user);
    }
     //NFT原拥有者置为0地址
    tokenIdToOriginalAddress[_tokenId] = address(0);
  }
/*
cancel Offer and withdraw NFT from contract
reject the best price means cancel all the offer
取消所有offer 并取回NFT到自己地址
*/
  function cancelAllOfferAndWithdrawFromSellList(uint _tokenId) public onlyOriginalOwnerOf(_tokenId){
    //NFT从合约取回
    oneRingNFT.transferFrom(address(this), msg.sender, _tokenId);
    //cancel every offers , refund or update userFunds 取消所有offer
    uint[] memory offerIdsOfTokenId = tokenIdToOfferIds[_tokenId];
    for(uint index = 0; index < offerIdsOfTokenId.length; index++){
      uint offerIdOfIndex = offerIdsOfTokenId[index];
      _Offer memory offerIndex = allOffers[offerIdOfIndex];
      require(offerIndex.offerstatus == OfferStatus.available, 'Offer status should be available');
      offerIndex.offerstatus = OfferStatus.cancelled;
      userFunds[offerIndex.user] += offerIndex.price;
      emit OfferCancelled(offerIndex.offerId, offerIndex.tokenId, offerIndex.user);
    }
     //NFT原拥有者置为0地址
    tokenIdToOriginalAddress[_tokenId] = address(0);
  }
/*
claim Funds
*/
  function claimFunds() public {
    require(userFunds[msg.sender] > 0, 'This user has no funds to be claimed');
    payable(msg.sender).transfer(userFunds[msg.sender]);
    userFunds[msg.sender] = 0; 
    emit ClaimFunds(msg.sender, userFunds[msg.sender]);   
  }

  /********************************** 查询 **********************************/
/*
request owner of nftid
*/
 function ownerOfNFTId(uint _tokenId)public view returns(address){
    address ownerOfNFT =  oneRingNFT.ownerOf(_tokenId);
    return ownerOfNFT;
  }
/*
request NFT balance of owner
*/
 function NFTbalanceOf(address _owner) public view returns (uint256) {
    uint256 balance =  oneRingNFT.balanceOf(_owner);
    return balance;
 }
 /*
request ETH balance of owner
*/
 function ETHbalanceOf(address _owner) public view returns (uint256) {
    uint256 balance =  userFunds[_owner];
    return balance;
 }
/*
request nftid of owner at index i
*/
function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256) {
    uint256 tokenId =  oneRingNFT.tokenOfOwnerByIndex(_owner, _index);
    return tokenId;
}
/*
  request tokenURI of nftid
*/
 function tokenURIOfNFTId(uint _tokenId)public view returns(string memory){
    string memory tokenURI =  oneRingNFT.tokenURI(_tokenId);
    return tokenURI;
 }


/*
request best price of nftid
*/
  function bestOfferOfNFTId(uint _tokenId)public view returns(_Offer memory){
    uint  bestOfferId = tokenIdToBestOfferId[_tokenId];
    return allOffers[bestOfferId];
  }

/*
request all offers for nftid
*/
  function offerIdsOfNFTId(uint _tokenId)public view returns(uint[] memory){
    uint[] memory offerIdsOfId = tokenIdToOfferIds[_tokenId];
    return offerIdsOfId;
  }
/*
  request offer detail of offer id
*/
  function offerDataOfOfferId(uint _Offerid)public view returns(_Offer memory){
    _Offer memory offer = allOffers[_Offerid];
    return offer;
  }

  // Fallback: reverts if Ether is sent to this smart-contract by mistake
  fallback () external payable{
    //revert();
  }
  
  receive() external payable{
    userFunds[msg.sender] += msg.value;
  }
}
