// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../../libraries/PeggyToken.sol";

contract MockBTC is PeggyToken{
    function initialize() public initializer{
        super.initialize("Mocked Bitcoin","mBTC",_msgSender());
        mint(_msgSender(),2100*10**18);
    }
}
