// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../libraries/LibDiamond.sol";
import "../interfaces/IERC173.sol";

contract OwnershipFacet is IERC173 {
    function transferOwnership(address _owner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_owner);
    }

    function owner() external view override returns (address) {
        return LibDiamond.contractOwner();
    }
}
