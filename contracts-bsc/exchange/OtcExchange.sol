// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../interfaces/IBEP20.sol";

contract OtcExchange {
    //vault user's token x has y amount
    mapping(address=>mapping(address=>uint256)) public vault_user_token_amount;
    //vault token x has y amount in ads
    mapping(address=>mapping(address=>uint256)) public vault_user_token_inads;

    //ads selling token x amount for y amount
    //maker_account => pair[keccak256(abi.encodePacked(addressA,addressB))]=>(Address(A,B))=>amount(deposit)

    //maker open ads(user => buyToken => sellToken => [buyAmount,sellAmount,startTime])
    //sellAmount <= vault'user's amount-valut'user's inads
    mapping (address=>mapping(address=>mapping(address=>uint256[])) ) public maker_open_ads;
    
    //taker records:(maker=>buyToken=>sellToken=>[boughtAmount,soldAmount,happenTime])
    mapping (address=>mapping(address=>mapping(address=>uint256[])) ) public taker_records;

    //square-orderbook
    //keccak256(abi.encodePacked(addressA,addressB)), maker's address list
    mapping (bytes32=>address[]) public orderbook_selling;
    //keccak256(abi.encodePacked(addressA,addressB)), maker's address list
    mapping (bytes32=>address[]) public orderbook_buying;

    //keccak256(abi.encodePacked(addressA,addressB)), maker's address list
    mapping (bytes32=>uint256[]) public orderbook_selling__;
    //keccak256(abi.encodePacked(addressA,addressB)), maker's address list
    mapping (bytes32=>address[]) public orderbook_buying__;

}
