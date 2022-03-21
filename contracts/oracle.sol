// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";


contract NFTOracle is Ownable{
   // 批量转账的数量控制在200以下
    uint16 public arrayLimit = 200;
   //预言机合约部署

   constructor ()  {

   }

   //NFT
   enum NFTState {Undetected,Detected}
   struct NFT{
       NFTState state;//目前的状态
       string hash;//NFT哈希值
       string IPFS; //NFT的IPFS
       bool isDetected; // 是否经过检测
       bool result; //检测结果
       address uploader;// 送检者
   }
   uint public ID = 1;//检测系统中所有NFT编号
   mapping(uint=>NFT) private nfts; 
   
   //输入NFT哈希，查看其是否通过检测(可供用户调用)
   function checkNFTByHash(string memory _hash) public view returns(bool) {
       for(uint i=0;i<ID;i++){
            if(compareStrings(nfts[i].hash,_hash)&&nfts[i].result==true){
                return true;
            }
        }
        return false;
   }
   //输入NFT编号，查看送检情况（供检测者调用）1 返回检测结果
   function checkNFTByID(uint _ID) public view returns(bool){
    //    require(msg.sender == owner,"Only owner can check the NFT by ID!");
       require(_ID<ID,"This ID of NFT don't exists");
       NFT memory nft = nfts[_ID];
       return nft.result;
   }
    //输入NFT编号，查看送检情况（供检测者调用）2 返回NFT详情
   function checkNFTByIDDetail(uint _ID) public view returns(NFT memory){
    //    require(msg.sender == owner,"Only owner can check the NFT by ID!");
       require(_ID<ID,"This ID of NFT don't exists");
       NFT memory nft = nfts[_ID];
       return nft;
   }
   
   //NFT送检
   function uploadNFT(string memory _hash,string memory _ipfs)  public returns(uint256){
       require(hashIsExists(_hash)&&ipfsIsExists(_ipfs),"Unable to repeat the detection!");
       nfts[ID].hash = _hash;
       nfts[ID].IPFS = _ipfs;
       nfts[ID].state = NFTState.Undetected; 
       nfts[ID].isDetected = false;
       nfts[ID].result = false;
       nfts[ID].uploader = msg.sender;
       ID = ID+1;
       return ID-1;
   }

    //NFT检测情况更新 单独*
    function detectNFT(uint _ID,bool _result) public onlyOwner{
        // require(msg.sender == owner,"Only owner can detect the NFT!");
        require(nfts[_ID].isDetected==false&&nfts[_ID].state==NFTState.Undetected,"The NFT does not meet the detection conditions!");
        nfts[_ID].result = _result;
        nfts[ID].isDetected = true;
        nfts[ID].state = NFTState.Detected;
   }
    //NFT检测情况批量更新 批量*
    function batchDetectNFT(uint[] memory _ID,bool[] memory _result) public onlyOwner{
        // 判断批量转账交易的数量没有超过限制
        require(_ID.length <= arrayLimit, "length beyond arrayLimit");

        // 比较数组长度是否相等
        require(_ID.length==_result.length,"The length of _ID should equal to the length of _result");

        for(uint8 i = 0; i < _ID.length; i++){
            uint nftid = _ID[i];
            bool resulti = _result[i];
            require(nfts[nftid].isDetected==false&&nfts[nftid].state==NFTState.Undetected,"The NFT does not meet the detection conditions!");
            nfts[nftid].result = resulti;
            nfts[nftid].isDetected = true;
            nfts[nftid].state = NFTState.Detected;
        }
       
   }
   
   //判断该NFT是否满足检测条件，即该NFT是否已经送检过
    function  hashIsExists(string memory _hash) private view returns(bool){
        for(uint i=0;i<ID;i++){
            if(compareStrings(nfts[i].hash,_hash)){
                return false;
            }
        }
        return true;
    }
    function ipfsIsExists(string memory _ipfs) private view returns(bool){
        for(uint i=0;i<ID;i++){
            if(compareStrings(nfts[i].IPFS,_ipfs)){
                return false;
            }
        }
        return true;
    }
    
    function  compareStrings(string memory a, string memory b) private pure returns(bool) {
           return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }



}