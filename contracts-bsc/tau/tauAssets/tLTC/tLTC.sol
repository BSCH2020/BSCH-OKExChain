// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import '../../base/ElasticSupplyToken.sol';

contract tLTC is ElasticSupplyToken{
    using SafeMathUpgradeable for uint256;
    function initialize() public initializer{
        super.initialize("τLitecoin","τLTC");
    }
}
