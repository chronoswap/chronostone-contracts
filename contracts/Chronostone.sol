// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

// TODO Add securities after tests

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import './BEP20.sol';

contract Chronostone is ERC1155 {
  // Global variables
  address public admin;
  uint256 public index = 1;
  uint256 public constant cardsByAirdrop = 5;
  uint256 public availableGens = 1;
  uint256 constant maxHatchingTime = 3110400;
  mapping (uint256 => uint256) prices;
  // Contracts
  BEP20 thop;
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
  struct airDrop {
    uint256[cardsByAirdrop] cards;
  }
  // Mappings
  mapping (uint256 => crateInfo) public metaCrates;
  mapping (uint256 => cardInfo) public metaCards;
  mapping (uint256 => airDrop) airDrops;
  mapping (address => uint256[]) balanceByAddress;
  mapping (address => uint256[]) airDropBalanceByAddress;
  // Arrays
  uint256[] public airdropIds;
  // Events
  event crateLaid(address to, uint256 gen, uint256 id);
  event cardCreated(uint256 id, uint256 gen, uint256 hatchTime);
  event airDropMinted(uint256 id, address to);
  // Modifiers
  modifier onlyAdmin() {
    require(msg.sender == admin, "Chronostone: You are not the CardMaker.");
    _;
  }
  modifier onlyOwner(address _sender, uint256 _id) {
    require(balanceOf(_sender, _id) > 0, "Chronostone: You are not the Owner of this NFT.");
    _;
  }
  modifier onlyCrate(uint256 _id) {
    require(metaCrates[_id].id != uint256(0), "Chronostone: This is not a crate.");
    _;
  }
  modifier onlyCard(uint256 _id) {
    require(metaCards[_id].id != uint256(0), "Chronostone: This is not a card.");
    _;
  }
  modifier hasBeenMinted(uint256 _id) {
    require(_id < index, "Chronostone: Wrong Id.");
    _;
  }
  modifier hasBeenCreated(uint256 _id) {
    require(airDrops[_id].cards[0] > 0, "Chronostone: Wrong Airdrop Id.");
    _;
  }
  modifier validGeneration(uint256 _gen) {
    require(_gen >= 1, "Chronostone: Invalid generation.");
    require(_gen <= availableGens, "Chronostone: Generation not available.");
    _;
  }
  // Functions
  constructor(string memory _uri, address _nativeToken) ERC1155(_uri) {
    admin = msg.sender;
    thop = BEP20(_nativeToken);
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
  function layCrate(address _to, uint256 _gen, uint256 _amount) public validGeneration(_gen) returns(uint256[] memory){
    require(_amount > 0, "Chronostone: Set amount >= 1.");
    uint256[] memory _id = new uint256[](_amount);
    uint256[] memory _amounts = new uint256[](_amount);
    thop.transferFrom(_to, address(this), prices[_gen] * thop.decimals() * _amount);
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
    require(!metaCrates[_id].isHatching, "Chronostone: This crate is already being hatched.");
    metaCrates[_id].isHatching = true;
    metaCrates[_id].hatchedTime = block.timestamp;
  }
  function unHatchCrate(uint256 _id) public onlyCrate(_id) onlyOwner(msg.sender, _id) {
    require(metaCrates[_id].isHatching, "Chronostone: This crate is not being hatched.");
    metaCrates[_id].isHatching = false;
    uint256 _delta = block.timestamp - metaCrates[_id].hatchedTime;
    metaCrates[_id].cumulativeHatchedTime += _delta;
  }
  function popCrate(uint256 _id) public onlyCrate(_id) onlyOwner(msg.sender, _id) {
    require(!metaCrates[_id].isHatching, "Chronostone: This crate is being hatched.");
    cardInfo memory _poppedCard;
    _poppedCard.id = metaCrates[_id].id;
    _poppedCard.gen = metaCrates[_id].gen;
    metaCards[_id] = _poppedCard;
    emit cardCreated(_id, _poppedCard.gen, metaCrates[_id].cumulativeHatchedTime);
    delete metaCrates[_id];
  }
  function createAirdrop() public onlyAdmin returns(uint256) {
    airDrop memory _newAirdrop;
    for (uint i=0; i<cardsByAirdrop; i++) {
      cardInfo memory _newCard;
      _newCard.id = index;
      _newCard.gen = 0;
      metaCards[index] = _newCard;
      airDropBalanceByAddress[address(this)].push(index);
      _newAirdrop.cards[i] = index;
      emit cardCreated(index, 0, 0);
      index ++;
    }
    airDrops[index] = _newAirdrop;
    airdropIds.push(index);
    index ++;
    return index - 1;
  }
  function sendAirdrop(uint256 _id, address _to) public hasBeenCreated(_id) onlyAdmin returns(bool) {
    airDrop memory _newAirdrop = airDrops[_id];
    uint256[] memory _amounts = new uint256[](cardsByAirdrop);
    uint256[] memory _ids = new uint256[](cardsByAirdrop);
    for (uint i=0; i<cardsByAirdrop; i++) {
      _amounts[i] = 1;
      _ids[i] = _newAirdrop.cards[i];
    }
    _mint(_to, _id, 1, "");
    _mintBatch(_to, _ids, _amounts, "");
    emit airDropMinted(_id, _to);
    return true;
  }
  function getAirdrop(uint256 _id) public view hasBeenCreated(_id) returns(airDrop memory) {
    return airDrops[_id];
  }
}
