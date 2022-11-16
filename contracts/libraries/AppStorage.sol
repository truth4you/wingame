// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

struct Round {
    uint32 id;
    uint32 countTotal;
    uint32 countSold;
    address currency;
    uint32 limit;
    uint256 price;
    mapping(address => bool) claimed;
    mapping(address => uint32) accounts;    // buyer => count
    mapping(uint32 => address) tickets;     // ticket => buyer
    mapping(uint32 => uint32) result1;      // position => ticket
    mapping(uint32 => uint32) result2;      // ticket => position
    mapping(uint32 => uint256) words;
    address sponsor;
    uint32 timeStart;
    uint32 timeEnd;
    uint8 status; // 0-Created, 1-Started, 2-Drawn, 3-Finished, 4-Closed
}

struct AppStorage {
    uint32 count;
    mapping(uint32 => Round) rounds;
    mapping(uint256 => uint32) requests;
    // Portion of distribute
    uint32 portionPrize;
    uint32 portionTresury;
    // Membership
    address token;
    uint256 threshold;
    // VRF settings
    address VRFcoordinator;
    uint64  VRFsubscription;
    bytes32 VRFhash;
}
