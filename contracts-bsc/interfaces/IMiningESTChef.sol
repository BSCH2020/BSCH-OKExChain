// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

interface IMiningESTChef {
    function mintMoreDelta(uint256 delta,uint256 timeInSeconds) external;
    function shrinkNoticedByPolicy(uint256 delta,uint256 newTotal)external;
}

library IMiningESTChefLib{
    uint256 public constant DEFAULT_DECIMAL = 18;
    uint256 public constant DEFAULT_EST_DECIMAL = 9;
}
