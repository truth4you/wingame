// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConsumer {
    function rawFulfillRandomWords(uint256, uint256[] memory) external;
}

contract VRFCoordinator {
    uint64 private lastSub;
    uint64 private lastRequest;
    mapping(uint64 => address) private subscriptions;
    mapping(uint64 => bytes32) private hashes;
    mapping(uint64 => uint256[]) private words;

    event Request(uint64, uint64);

    function createSubscription(address _consumer) public returns (uint64) {
        subscriptions[lastSub] = _consumer;
        hashes[lastSub] = keccak256(abi.encode(_consumer));
        lastSub++;
        return lastSub - 1;
    }
    function setSubscription(uint64 _sub, bytes32 _hash, address _consumer) public {
        subscriptions[_sub] = _consumer;
        hashes[_sub] = _hash;
    }
    function getSubscription(uint64 _sub) public view returns (address, bytes32) {
        return (
            subscriptions[_sub], hashes[_sub]
        );
    }
    function requestRandomWords(
        bytes32 _hash,
        uint64 _sub,
        uint16 _confirmations,
        uint32 _gas,
        uint32 _count
    ) public returns (uint256) {
        require(hashes[_sub]==_hash, "Unregistered consumer.");
        uint64 _requestId = lastRequest++;
        uint256[] storage _words = words[_requestId];
        for(uint32 i = 0;i<_count;i++) {
            uint256 _random = uint256(
                keccak256(abi.encode(block.timestamp, _confirmations, _gas, i))
            );
            _words.push(_random);
        }
        emit Request(_sub, _requestId);
        return _requestId;
    }
    function fulfillRandomWords(uint64 _sub, uint64 _requestId) public {
        uint256[] storage _words = words[_requestId];
        IConsumer(subscriptions[_sub]).rawFulfillRandomWords(_requestId, _words);
    }
}