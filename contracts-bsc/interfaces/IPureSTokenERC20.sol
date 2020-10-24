// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
import "./ISTokenERC20.sol";

interface IPureSTokenERC20 is ISTokenERC20{    
    function getOwner() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function mint(address to, uint256 amount) external;
    function transferOwnership(address newOwner) external;

    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    
    function mintWithTimeLock(address account, uint256 amount) external;
    function transferLockedTo(address to,uint256 amount) external returns(uint[] memory,uint256[] memory);
    function transferLockedFromFarmWithRecord(address recipient,
        uint256 amount,uint[] memory tobeCostKeys,uint256[] memory tobeCost) external;
}
