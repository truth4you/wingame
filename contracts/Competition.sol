// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
// import "hardhat/console.sol";

struct SoldEvent {
    address account;
    uint32 index;
    uint32 amount;
    uint32 time;
}

struct Competition {
    uint256 id;
    uint32 countTotal;
    uint32 countSold;
    uint256 price;
    uint32 maxPerPerson;
    uint256 timeStart;
    uint256 timeEnd;
    address winner;
    address sponser;
    string url;
    uint8 status; // 0-Created, 1-Started, 2-Drawn, 3-Finished, 4-Closed
}

contract Competitions is ERC20Upgradeable {
    address private owner;
    address private agent;

    Competition[] public competitions;
    // mapping(address => bool) public sponsers;
    mapping(address => mapping(uint256 => uint32)) public ticketPerson;
    mapping(uint256 => SoldEvent[]) public histories;
    mapping(uint256 => SoldEvent) public winning;
    mapping(uint256 => bool) public allowed;
    address public token;
    uint256 public discount5;
    uint256 public discount10;
    uint256 public rateCancel;

    VRFCoordinatorV2Interface coordinator;
    uint64 private subscriptionId;
    bytes32 private keyHash;
    mapping(uint256 => uint256) private drawRequests;
    mapping(uint256 => uint256) private drawResults;
    bool public canDrawMiddle;

    event Created(uint256 indexed);
    event Updated(uint256 indexed);
    event Allowed(uint256 indexed);
    event Drawn(uint256 indexed, uint256);
    event Finished(uint256 indexed, address);
    event Closed(uint256 indexed);

    function initialize(address tokenAddress) public initializer {
        owner = msg.sender;
        // sponsers[msg.sender] = true;
        token = tokenAddress;
        discount5 = 0;
        discount10 = 0;
        rateCancel = 5000;
    }

    function updateVRF(address _coordinatior, uint64 _sub, bytes32 _hash) public forOwner {
        coordinator = VRFCoordinatorV2Interface(_coordinatior);
        subscriptionId = _sub;
        keyHash = _hash;
    }
    
    modifier forOwner() {
        require(owner == msg.sender, "Modifier: Only owner call.");
        _;
    }

    modifier forAgent() {
        require(owner == msg.sender, "Modifier: Only owner call.");
        _;
    }

    function setOwner(address _owner) public forOwner {
        owner = _owner;
    }

    // function setSponser(address account, bool active) public forOwner {
    //     sponsers[account] = active;
    // }

    function getCompetitions() public view returns (Competition[] memory) {
        Competition[] memory id = new Competition[](competitions.length);
        for (uint256 i = 0; i < competitions.length; i++) {
            Competition storage competition = competitions[i];
            id[i] = competition;
        }
        return id;
    }

    function create(
        uint32 countTotal,
        uint256 price,
        uint32 maxPerPerson,
        string memory url
    ) public payable {
        require(countTotal > 0, "Create: CountTotal must be positive.");
        require(
            maxPerPerson > 0 && maxPerPerson <= countTotal,
            "Create: MaxPerPerson is invalid."
        );
        require(
            price > 0,
            "Create: Invalid Price."
        );
        uint256 idNew = competitions.length + 1;
        competitions.push(
            Competition({
                id: idNew,
                countTotal: countTotal,
                countSold: 0,
                price: price,
                maxPerPerson: maxPerPerson,
                timeStart: 0,
                timeEnd: 0,
                winner: address(0),
                sponser: msg.sender,
                url: url,
                status: 0
            })
        );
        emit Created(idNew);
    }

    function update(
        uint256 id,
        uint32 countTotal,
        uint256 price,
        uint32 maxPerPerson,
        string memory url
    ) public {
        require(id > 0 && id <= competitions.length, "Update: Invalid id.");
        require(countTotal > 0, "Update: CountTotal must be positive.");
        require(
            maxPerPerson > 0 && maxPerPerson <= countTotal,
            "Update: MaxPerPerson is invalid."
        );
        require(
            price > 0,
            "Update: Invalid Price."
        );
        Competition storage competition = competitions[id - 1];
        require(owner == msg.sender || competition.sponser == msg.sender, "Only sponser can update.");
        require(id == competition.id, "Update: Unregistered competition.");
        require(competition.status == 0, "Update: Competition was started.");
        competition.countTotal = countTotal;
        competition.price = price;
        competition.maxPerPerson = maxPerPerson;
        competition.url = url;
    }

    function allow(uint256 _id) public forOwner {
        allowed[_id] = true;
    }

    function start(uint256 _id, uint256 _endTime) public {
        require(_id > 0 && _id <= competitions.length, "Start: Invalid id.");
        Competition storage competition = competitions[_id - 1];
        require(owner == msg.sender || competition.sponser == msg.sender, "Only sponser can start.");
        require(owner == msg.sender || allowed[_id], "Start: Competition was not allowed by owner.");
        require(competition.status == 0, "Start: Competition was started.");
        require(
            _endTime > block.timestamp,
            "Start: EndTime must be later than now."
        );
        competition.timeStart = block.timestamp;
        competition.timeEnd = _endTime;
        competition.status = 1;
    }

    function canDraw(uint256 id) public view returns (bool) {
        require(id > 0 && id <= competitions.length, "Draw: Invalid id.");
        Competition storage competition = competitions[id - 1];
        require(owner == msg.sender || competition.sponser == msg.sender, "Only sponser can draw.");
        require(competition.status == 1, "Draw: Competition was not started.");
        // if(canDrawMiddle)
        //     require(competition.countSold == competition.countTotal, "Draw: all ticket must be sold!");
        // else
        //     require(
        //         competition.timeEnd <= block.timestamp,
        //         "Draw: Competition is not ready to draw."
        //     );
        
        require(competition.countSold > 0, "Draw: No ticket was sold.");
        require(histories[id - 1].length > 0, "Draw: No ticket was sold.");
        return true;
    }    

    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) public {
        if (msg.sender == address(coordinator)) {
            uint256 id = drawRequests[requestId];
            if(id>0) {
                Competition storage competition = competitions[id - 1];
                drawResults[id] = randomWords[0];
                drawRequests[requestId] = 0;
                competition.status = 2;
                emit Drawn(id, randomWords[0]);
            }
        }
    }

    function finish(uint256 _id) public {
        require(_id > 0 && _id <= competitions.length, "Finish: Invalid id.");
        require(drawResults[_id] > 0, "Finish: Does not drawn by VRF.");
        Competition storage competition = competitions[_id - 1];
        require(owner == msg.sender || competition.sponser == msg.sender, "Only sponser can finish.");
        require(competition.status == 2, "Finish: Competition was not drawn.");
        require(competition.winner == address(0), "Finish: Competition was already finished.");
        competition.status = 3;
        SoldEvent[] storage history = histories[_id - 1];
        uint256 seed = drawResults[_id] % competition.countSold;
        uint256 sum = 0;
        uint256 i = 0;
        for (i = 0; i < history.length; i++) {
            if (history[i].amount == 0) continue;
            sum = sum + history[i].amount;
            if (sum > seed) {
                competition.winner = history[i].account;
                winning[_id] = history[i];
                winning[_id].index = uint32(sum - seed);
                // delete histories[_id - 1];
                emit Finished(_id, competition.winner);
                break;
            }
        }
    }

    function draw(uint256 _id) public {
        if(canDraw(_id)) {
            uint256 requestId = coordinator.requestRandomWords(
                keyHash,
                subscriptionId,
                3,
                100000,
                1
            );
            drawRequests[requestId] = _id;
        }       
    }

    function buy(uint256 _id, uint32 _count, address _buyer) public {
        require(_id > 0 && _id <= competitions.length, "Buy: Invalid id.");
        Competition storage competition = competitions[_id - 1];
        require(competition.status == 1, "Buy: Competition is not pending.");
        require(
            competition.timeEnd > block.timestamp,
            "Buy: Competition is timeout."
        );
        uint256 price = competition.price * _count;
        if (_count >= 10) price -= (price * discount10) / 10000;
        else if (_count >= 5) price -= (price * discount5) / 10000;
        if(msg.sender != agent) {
            _buyer = msg.sender;
            require(IERC20(token).balanceOf(_buyer) >= price,
                "Buy: Insufficent balance."
            );
            IERC20(token).transferFrom(
                _buyer,
                address(this),
                price
            );
        }
        ticketPerson[_buyer][_id] += _count;
        competition.countSold += _count;
        require(competition.countSold <= competition.countTotal, "Buy: There is no enough ticket");
        require(
            ticketPerson[_buyer][_id] <= competition.maxPerPerson,
            "Buy: You cannot buy more than MaxPerPerson."
        );
        SoldEvent[] storage history = histories[_id - 1];
        history.push(SoldEvent({account: _buyer, index: 0, amount: _count, time: uint32(block.timestamp)}));
    }

    function tickets(address _account, uint256 _id) public view returns(uint32){
        return ticketPerson[_account][_id];
    }

    function cancel(uint256 _id, uint32 _count) public {
        require(_id > 0 && _id <= competitions.length, "Sell: Invalid id.");
        Competition storage competition = competitions[_id - 1];
        require(competition.status == 1, "Sell: Competition is not pending.");
        require(
            competition.timeEnd > block.timestamp,
            "Sell: Competition is timeout."
        );
        require(
            ticketPerson[msg.sender][_id] >= _count,
            "Sell: You didnot purchase so."
        );
        uint256 price = competition.price * _count * rateCancel / 10000;
        IERC20(token).transfer(address(msg.sender), price);
        ticketPerson[msg.sender][_id] -= _count;
        competition.countSold -= _count;
        SoldEvent[] storage history = histories[_id - 1];
        uint256 i = 0;
        for (i = 0; i < history.length; i++) {
            if (msg.sender == history[i].account && history[i].amount > 0) {
                if (_count > history[i].amount) {
                    _count -= history[i].amount;
                    history[i].amount = 0;
                } else {
                    history[i].amount -= _count;
                    _count = 0;
                }
                if (_count == 0) break;
            }
        }
    }

    function withdraw(uint256 _amount, address _recipient) public forOwner {
        require(
            IERC20(token).balanceOf(address(this)) >= _amount,
            "Withdraw: Insufficent balance."
        );
        IERC20(token).transfer(_recipient, _amount);
    }

    function close(uint32 _id) public {
        require(_id > 0 && _id <= competitions.length, "Close: Invalid id.");
        Competition storage competition = competitions[_id - 1];
        require(competition.status == 3, "Competition is not finished.");
        require(owner == msg.sender || competition.winner == msg.sender, "Only winner can close.");
        competition.status = 4;
    }

    function setDiscount5(uint256 _discount) public forOwner {
        discount5 = _discount;
    }

    function setDiscount10(uint256 _discount) public forOwner {
        discount10 = _discount;
    }

    function setRateCancel(uint256 _rate) public forOwner {
        rateCancel = _rate;
    }

    function setToken(address _token) public forOwner {
        token = _token;
    }

    function setCanDrawMiddle(bool _canDraw) public forOwner {
        canDrawMiddle = _canDraw;
    }
}
