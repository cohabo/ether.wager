pragma solidity ^0.4.8;

import "./CfdMarket.sol";

contract TestableCfdMarket is CfdMarket {
  modifier oraclizeAPI {
      _;
  }
  function oraclize_cbAddress() oraclizeAPI internal returns (address){
    return msg.sender;
  }

  function oraclize_getPrice(string arg, uint gas) oraclizeAPI internal returns (uint) {
    return 10000;
  }

  function oraclize_query(string datasource, string arg, uint gas) oraclizeAPI internal returns (bytes32 id){
    return 0x0;
  }
}
