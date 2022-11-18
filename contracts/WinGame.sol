// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SolidStateDiamond } from '@solidstate/contracts/proxy/diamond/SolidStateDiamond.sol';
import "./libraries/AppStorage.sol";

contract WinGame is SolidStateDiamond {
    function init() public {
        AppStorage.ConfigStorage storage config = AppStorage.getConfigStorage();
        config.portionPrize = 9000;     // 90 %
        config.intervalDraw = 60;       // 60 secs
    }
}
