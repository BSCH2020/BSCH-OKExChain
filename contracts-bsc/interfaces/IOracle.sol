// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
import "./ISTokenERC20.sol";

interface IOracle {
    function getData() external view returns (uint256);
    function update() external;
}
