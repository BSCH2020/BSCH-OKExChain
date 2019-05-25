// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;


interface IFarm{
    function depositToMining(uint256 amount)external;
    function depositToMiningBySTokenTransfer(address from,uint256 amount)external;
}
