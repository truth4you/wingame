// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { OwnableInternal } from '@solidstate/contracts/access/ownable/OwnableInternal.sol';
import "../libraries/AppStorage.sol";
// import "../libraries/LibDiamond.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "hardhat/console.sol";

contract CompetitionFacet is OwnableInternal {
    event Created(uint32 indexed);
    event Updated(uint32 indexed);
    event Started(uint32 indexed);
    event Drawn(uint32 indexed);
    event Finished(uint32 indexed);
    event Closed(uint32 indexed);
    event Sold(uint32 indexed, address indexed, uint32);

    // constructor() {
    //     LibDiamond.setContractOwner(msg.sender);
    //     s.portionPrize = 9000;
    // }

    function updateVRF(address _coordinator, uint64 _subscription, bytes32 _hash) public onlyOwner {
        AppStorage.VRFStorage storage vrf = AppStorage.getVRFStorage();
        vrf.coordinator = _coordinator;
        vrf.subscription = _subscription;
        vrf.keyhash = _hash;
    }

    function updateThreshold(address _token, uint256 _threshold) public onlyOwner {
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        config.token = _token;
        config.threshold = _threshold;
    }

    function updateInterval(uint32 _interval) public onlyOwner {
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        config.intervalDraw = _interval;
    }

    function updatePortionPrize(uint32 _portion) public onlyOwner {
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        config.portionPrize = _portion;
    }

    function updatePortionTreasury(uint32 _portion) public onlyOwner {
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        config.portionTreasury = _portion;
    }

    function create(
        uint32 _countTotal,
        uint256 _price,
        address _currency
    ) public onlyOwner {
        require(_countTotal > 0, "Create: ticket count is negative.");
        require(_price > 0, "Create: price is negative.");
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        Round storage round = s.rounds[s.count++];
        round.id = s.count;
        round.countTotal = _countTotal;
        round.price = _price;
        round.currency = _currency;
        // round.sponsor = msg.sender;
        round.limit = 1;
        emit Created(round.id);
    }

    function update(
        uint32 _index,
        uint32 _countTotal,
        uint256 _price,
        address _currency
    ) public onlyOwner {
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        require(_index < s.count, "Update: round does not exist.");
        require(_countTotal > 0, "Update: ticket count is negative.");
        require(_price > 0, "Update: price is negative.");
        Round storage round = s.rounds[_index];
        require(round.status == 0, "Update: round was started or finished yet.");
        round.countTotal = _countTotal;
        round.price = _price;
        round.currency = _currency;
        emit Updated(round.id);
    }

    function start(uint32 _index) public onlyOwner {
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        require(_index < s.count, "Start: round does not exist.");
        Round storage round = s.rounds[_index];
        require(round.status == 0, "Update: round was started or finished yet.");
        round.timeStart = uint32(block.timestamp);
        // round.countSold = 0;
        round.status = 1;
        emit Started(round.id);
    }

    function _drawable(uint32 _index) private view returns (bool) {
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        require(_index <= s.count, "Draw: invalid round.");
        Round storage round = s.rounds[_index];
        require(round.status == 1, "Draw: round was not started.");
        require(round.countSold > 0, "Draw: No ticket was sold.");
        return true;
    } 

    function draw(uint32 _index) public onlyOwner {
        _drawable(_index);
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        AppStorage.VRFStorage storage vrf = AppStorage.getVRFStorage();
        Round storage round = s.rounds[_index];
        VRFCoordinatorV2Interface coordinator = VRFCoordinatorV2Interface(vrf.coordinator);
        uint256 _requestId = coordinator.requestRandomWords(
            vrf.keyhash,
            vrf.subscription,
            3,
            100000,
            round.countSold - 1
        );
        vrf.requests[_requestId] = _index + 1;
    }

    function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) public {
        AppStorage.VRFStorage storage vrf = AppStorage.getVRFStorage();
        if (msg.sender == vrf.coordinator && vrf.requests[_requestId] > 0) {
            AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
            Round storage round = s.rounds[vrf.requests[_requestId] - 1];
            for(uint32 i = 0;i<round.countSold - 1;i++) {
                round.words[i] = _randomWords[i];
            }
            round.status = 2;
            // delete vrf.requests[_requestId];
            emit Drawn(round.id);
        }
    }

    function finish(uint32 _index) public onlyOwner {
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        require(_index <= s.count, "Finish: invalid round.");
        Round storage round = s.rounds[_index];
        require(round.status == 2, "Finish: round was not drawn.");
        round.status = 3;
        round.timeEnd = uint32(block.timestamp);
        uint32 j = 0;
        uint32[] memory orders = new uint32[](round.countSold);
        for(uint32 i = 0;i<round.countTotal;i++) {
            if(round.tickets[i]!=address(0)) {
                orders[j++] = i;
            }
        }
        for(uint32 i = 0;i<round.countSold;i++) {
            uint32 pos = uint32(round.words[i] % (round.countSold - i)) + i;
            (orders[i], orders[pos]) = (orders[pos], orders[i]);
            round.result1[i + 1] = orders[i];
            round.result2[orders[i]] = i + 1;
        }
        emit Finished(round.id);
    }

    function remains(uint32 _index) public view returns (uint32[] memory) {
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        Round storage round = s.rounds[_index];
        uint32[] memory tickets = new uint32[](round.countTotal - round.countSold);
        if(round.countTotal==round.countSold) return tickets;
        uint32 j = 0;
        for(uint32 i = 0;i<round.countTotal;i++) {
            if(round.tickets[i]==address(0)) {
                tickets[j++] = i;
            }
        }
        return tickets;
    }

    function mine(uint32 _index) public view returns (uint32[] memory, uint32[] memory, uint256) {
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        Round storage round = s.rounds[_index];
        if(round.accounts[msg.sender]==0) return (new uint32[](0), new uint32[](0), 0);
        uint32[] memory tickets = new uint32[](round.accounts[msg.sender]);
        uint32[] memory positions = new uint32[](round.accounts[msg.sender]);
        uint256[] memory claims = prizes(_index);
        uint256 claimable = 0;
        uint32 j = 0;
        uint32 count = (uint32(block.timestamp) - round.timeEnd) / config.intervalDraw;
        if(count > round.countSold) count = round.countSold;
        for(uint32 i = 0;i<round.countTotal;i++) {
            if(round.tickets[i]==msg.sender) {
                tickets[j] = i;
                if(round.result2[i] <= count) {
                    positions[j] = round.result2[i];
                    claimable += claims[round.result2[i] - 1];
                }
                j++;
            }
        }
        return (tickets, positions, claimable);
    }

    function result(uint32 _index) public view returns (uint32[] memory) {
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        Round storage round = s.rounds[_index];
        uint32 count = (uint32(block.timestamp) - round.timeEnd) / config.intervalDraw;
        if(count > round.countSold) count = round.countSold;
        uint32[] memory tickets = new uint32[](count);
        if(round.status!=3) return tickets;
        for(uint32 i = 0;i<count;i++) {
            tickets[i] = round.result1[i+1];
        }
        return tickets;
    }

    function prizes(uint32 _index) public view returns (uint256[] memory) {
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        Round storage round = s.rounds[_index];
        require(round.status==3, "Prize: round is not finised.");
        uint256 total = round.price * round.countSold * config.portionPrize / 10000;
        uint256[] memory amounts = new uint256[](round.countSold);
        for(uint32 i = 0;i<round.countSold && i<3;i++) {
            amounts[i] = total / 2;
            total -= amounts[i];
        }
        if(round.countSold > 4) {
            uint256 common = total * 10 * 8 / 10000; // 0.1%
            uint256 step = total * 8 * (2560 - 20 * round.countSold) / 10000 / (round.countSold - 3) / (round.countSold - 4);
            for(uint32 i = round.countSold-2;i>=3;i--) {
                common += step; 
                amounts[i] = common;
                total -= common;
            }
        }
        if(round.countSold > 3)
            amounts[round.countSold-1] = total;
        return amounts;
    }

    function buy(uint32 _index) payable public {
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        require(_index <= s.count, "Buy: invalid round.");
        Round storage round = s.rounds[_index];
        require(round.status == 1, "Buy: round was not started.");
        require(round.countTotal > round.countSold, "Buy: all ticket have already sold");
        require(round.accounts[msg.sender] < round.limit, "Buy: cannot buy more.");
        if(config.token!=address(0) && config.threshold>0)
            require(IERC20(config.token).balanceOf(msg.sender) >= config.threshold, "Buy: insufficient membership.");
        if(round.currency==address(0)) {
            require(msg.value==round.price, "Buy: insufficient ETH.");
        } else {
            require(IERC20(round.currency).balanceOf(msg.sender) >= round.price,
                "Buy: insufficent balance."
            );
            IERC20(round.currency).transferFrom(msg.sender, address(this), round.price);
        }
        uint256 seed = uint256(keccak256(abi.encode(block.timestamp, block.difficulty, round.id, msg.sender))) % (round.countTotal - round.countSold);
        uint32[] memory tickets = remains(_index);
        uint32 ticket = tickets[seed];
        round.accounts[msg.sender] ++;
        round.tickets[ticket] = msg.sender;
        round.countSold ++;
        emit Sold(_index, msg.sender, ticket);
    }

    function claim(uint32 _index) public {
        AppStorage.CompetitionStorage storage s = AppStorage.getCompetitionStorage();
        require(_index <= s.count, "Claim: invalid round.");
        Round storage round = s.rounds[_index];
        require(round.status == 3, "Claim: round was not finished.");
        require(!round.claimed[msg.sender], "Claim: already claimed.");
        require(round.accounts[msg.sender] > 0, "Claim: did not buy ticket.");
        (,,uint256 claimable) = mine(_index);
        require(claimable > 0, "Claim: no claimable.");
        if(round.currency==address(0))
            payable(msg.sender).transfer(claimable);
        else
            IERC20(round.currency).transfer(msg.sender, claimable);
        round.claimed[msg.sender] = true;
    }

    function withdraw(address _token, address _to, uint256 _amount) public onlyOwner {
        if(_token==address(0)) {
            payable(_to).transfer(_amount);
        } else {
            IERC20(_token).transfer(_to, _amount);
        }
    }
}
