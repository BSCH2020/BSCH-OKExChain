// SPDX-License-Identifier: MIT
pragma solidity>=0.5.4;


import "../libraries/PeggyToken.sol";

contract BSCHTron is PeggyToken{
    constructor() public{
        super.initialize("Bitcoin Bitcoin Standard Circulation Hashrate Token Token","BSCH",_msgSender());
    }
    function adminUpgradeDecimal(uint8 decimals_) public onlyOwner{
        _setupDecimals(decimals_);
    }
}
