// SPDX-License-Identifier: MIT
pragma solidity >=0.6.9;
pragma experimental ABIEncoderV2;

import "./MayaBridge.sol";

contract TronMayaBridge is MayaBridge{
    function initialize()public override initializer{
        //main chain
        super.initialize(true);
    }
}
