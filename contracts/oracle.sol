// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract NFTOracle  {
   
   //预言机合约部署
   address owner;//AI检测地址
   constructor ()  {
       owner = msg.sender;
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
   uint public ID = 0;//检测系统中所有NFT编号
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
   //输入NFT编号，查看送检情况（供检测者调用）
   function checkNFTByID(uint _ID) public view returns(bool) {
       require(msg.sender == owner,"Only owner can check the NFT by ID!");
       require(_ID<ID,"This ID of NFT don't exists");
       NFT memory nft = nfts[_ID];
       return nft.result;
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
       ID++;
       return ID;
   }

    //NFT检测情况更新
    function detectNFT(uint _ID,bool _result) public {
        require(msg.sender == owner,"Only owner can detect the NFT!");
        require(nfts[_ID].isDetected==false&&nfts[_ID].state==NFTState.Undetected,"The NFT does not meet the detection conditions!");
        nfts[_ID].result = _result;
        nfts[ID].isDetected = false;
        nfts[ID].state = NFTState.Detected;
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