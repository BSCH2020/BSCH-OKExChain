// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import './UpgradeableBase.sol';
import '../interfaces/IWhitelist.sol';

abstract contract LWhitelisted is UpgradeableBase{
    IWhitelist public whitelist;

    modifier onlyWhitelisted(bytes32[] calldata proof){
        require(
            whitelist.whitelisted(_msgSender(), proof),"Caller is not whitelisted / proof invalid"
        );
        _;
    }
}
