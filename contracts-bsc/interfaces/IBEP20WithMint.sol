// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "./IBEP20.sol";
interface IBEP20WithMint is IBEP20{
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external; 
}
