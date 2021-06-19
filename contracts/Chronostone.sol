pragma solidity ^0.8.3;

//SPDX-License-Identifier: MIT

// TODO Add securities after tests

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import './BEP20.sol';  // Cambiarlo por el token nativo

contract Chronostone is ERC1155 {
  // Global variables
  address public admin;
  uint256 public index = 1;
  uint256 maxHatchingTime = 3110400;
  uint256 decimals = 6;
  mapping (uint256 => uint256) prices;
  // Contracts
  BEP20 oneK;
  // Structs
  struct crateInfo {
    bool isHatching;
    uint256 hatchModifier; // TODO pendiente definir detalles de esto
    uint256 id;
    uint256 gen;
    uint256 hatchedTime;
    uint256 cumulativeHatchedTime;
  }
  struct cardInfo {
    uint256 id;
    uint256 gen;
  }
  // Mappings
  mapping (uint256 => crateInfo) public metaCrates;
  mapping (uint256 => cardInfo) public metaCards;
  mapping (address => uint256[]) balanceByAddress;

  // Events
  event crateLaid(address to, uint256 gen, uint256 id);
  event cardCreated(uint256 id, uint256 gen, uint256 hatchTime);

  // Modifiers
  modifier onlyAdmin() {
    require(msg.sender == admin, "Chronostone: You are not the Card Maker");
    _;
  }
  modifier onlyOwner(address _sender, uint256 _id) {
    require(balanceOf(_sender, _id) > 0, "Chronostone: You are not the Owner of this NFT");
    _;
  }
  modifier onlyCrate(uint256 _id) {
    require(metaCrates[_id].id != uint256(0), "Chronostone: This is not a crate");
    _;
  }
  modifier onlyCard(uint256 _id) {
    require(metaCards[_id].id != uint256(0), "Chronostone: This is not a card");
    _;
  }
  modifier hasBeenMinted(uint256 _id) {
    require(_id < index, "Wrong Id");
    _;
  }

  // Functions
  constructor(string memory _uri, address _nativeToken) ERC1155(_uri) {
    admin = msg.sender;
    oneK = BEP20(_nativeToken);
    for (uint i = 1; i <= 4; i++) {
      prices[i] = 200 * i;
    }
  }
  function getBalancesByAddress(address _account) public view returns(uint256[] memory){
    return balanceByAddress[_account];
  }
  function stateInfo(uint256 _id) public view hasBeenMinted(_id) returns(string memory) {
    if (metaCrates[_id].id > 0) {
      return "Crate";
    }
    return "Card";
  }
  function getCard(uint256 _id) public view onlyCard(_id) returns(cardInfo memory){
    return metaCards[_id];
  }
  function getCrate(uint256 _id) public view onlyCrate(_id) returns(crateInfo memory){
    return metaCrates[_id];
  }
  // TODO ver bien el workflow de esto para tener el allowance antes y enviarlo, etc
  function layCrate(address _to, uint256 _gen, uint256 _amount) public returns(uint256[] memory){
    require(_amount > 0, "Set amount >= 1");
    require(_gen >= 1, "Invalid generation");
    uint256[] memory _id = new uint256[](_amount);
    uint256[] memory _amounts = new uint256[](_amount);
    oneK.transferFrom(_to, address(this), prices[_gen] * oneK.decimals() * _amount);
    for (uint i=0; i<_amount; i++) {
      crateInfo memory _newCrate;
      _newCrate.isHatching = false;
      _newCrate.id = index;
      _newCrate.gen = _gen;
      _newCrate.hatchedTime = 0;
      _newCrate.cumulativeHatchedTime = 0;
      metaCrates[index] = _newCrate;
      balanceByAddress[_to].push(index);
      _amounts[i] = 1;
      _id[i] = index;
      emit crateLaid(_to, _gen, index);
      index ++;
    }
    _mintBatch(_to, _id, _amounts, "");
    return _id;
  }
  function hatchCrate(uint256 _id) public onlyCrate(_id) onlyOwner(msg.sender, _id) {
    require(!metaCrates[_id].isHatching, "This crate is already being hatched");
    metaCrates[_id].isHatching = true;
    metaCrates[_id].hatchedTime = block.timestamp;
  }
  function unHatchCrate(uint256 _id) public onlyCrate(_id) onlyOwner(msg.sender, _id) {
    require(metaCrates[_id].isHatching, "This crate is not being hatched");
    metaCrates[_id].isHatching = false;
    uint256 _delta = block.timestamp - metaCrates[_id].hatchedTime;
    metaCrates[_id].cumulativeHatchedTime += _delta;
  }
  function popCrate(uint256 _id) public onlyCrate(_id) onlyOwner(msg.sender, _id) {
    require(!metaCrates[_id].isHatching, "This crate is being hatched");
    cardInfo memory _poppedCard;
    _poppedCard.id = metaCrates[_id].id;
    _poppedCard.gen = metaCrates[_id].gen;
    metaCards[_id] = _poppedCard;
    emit cardCreated(_id, _poppedCard.gen, metaCrates[_id].cumulativeHatchedTime);
    delete metaCrates[_id];
  }
}
