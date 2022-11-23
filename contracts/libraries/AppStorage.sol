// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

library AppStorage {
    struct ConfigStorage {
        uint32 portionPrize;        // Portion of prize
        uint32 portionTreasury;      // Portion of tresury

        uint32 intervalDraw;        // Intervals between drawing in a round

        address token;              // Membership token
        uint256 threshold;          // Membership threshold
    }

    struct VRFStorage {
        address coordinator;
        uint64  subscription;
        bytes32 keyhash;
        mapping(uint256 => uint32) requests;
    }

    struct CompetitionStorage {
        uint32 count;
        mapping(uint32 => Round) rounds;
    }

	bytes32 constant STORAGE_CONFIG = keccak256('wingame/storage/config');
	function getConfigStorage() internal pure returns (ConfigStorage storage s) {
		bytes32 position = STORAGE_CONFIG;
		assembly {
			s.slot := position
		}
	}
    
	bytes32 constant STORAGE_VRF = keccak256('wingame/storage/VRF');
	function getVRFStorage() internal pure returns (VRFStorage storage s) {
		bytes32 position = STORAGE_VRF;
		assembly {
			s.slot := position
		}
	}

	bytes32 constant STORAGE_COMPETITION = keccak256('wingame/storage/competition');
	function getCompetitionStorage() internal pure returns (CompetitionStorage storage s) {
		bytes32 position = STORAGE_COMPETITION;
		assembly {
			s.slot := position
		}
	}
}
