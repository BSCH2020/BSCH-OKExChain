// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import '../../base/ESTPolicy.sol';

contract tBTCESTPolicy is ESTPolicy{
    using SafeMathUpgradeable for uint256;
    
    function initialize(address esToken) public initializer{
        super.__ESTPolicy_init_chained(esToken,address(0),2100);
    }
    
}
