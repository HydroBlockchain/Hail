pragma solidity ^0.5.0;

interface HSTBuyerRegistryInterface {
  function getTokenLegalStatus(address _tokenAddress) external view returns(bool);
  function checkRules(uint _buyerEIN) external view;
}
