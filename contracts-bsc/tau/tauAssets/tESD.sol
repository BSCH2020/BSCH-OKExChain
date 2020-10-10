// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import '../base/ElasticSupplyToken.sol';

contract tESD is ElasticSupplyToken{
    using SafeMathUpgradeable for uint256;
    function initialize() public initializer{
        super.initialize("τElastic USD","τESD");
    }
}
