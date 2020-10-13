// SPDX-License-Identifier: MIT
pragma solidity>=0.5.4;

import "./access/AccessControl.sol";
import "./utils/Pausable.sol";
import "./SafeERC20.sol";
import "../interfaces/IERC20.sol";

contract OwnableContract is AccessControl,Pausable{
    using SafeERC20 for IERC20;
    address public pendingOwner;
    address private _owner;
    // INITIALIZATION DATA
    bool public initialized;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    function _setupOwner(address owner_)internal{
        _owner = owner_;
    }
    /**
     * @dev confirms to BEP20
     */
    function getOwner() external view returns (address){
        return _owner;
    }
    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */
    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner);
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public  onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        pendingOwner = newOwner;
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnershipImmediately(address newOwner) public onlyOwner {
        require(address(0)!=newOwner,"not allowed to transfer owner to address(0)");
        _owner = newOwner;
        emit OwnershipTransferred(_owner, newOwner);
    }
    /**
     * @dev Allows the pendingOwner address to finalize the transfer.
     */
    function claimOwnership() public onlyPendingOwner {
        emit OwnershipTransferred(_owner, pendingOwner);
        _owner = pendingOwner;
        pendingOwner = address(0);
    }
    // File: openzeppelin-solidity/contracts/ownership/CanReclaimToken.sol

    /**
    * @title Contracts that should be able to recover tokens
    * @author SylTi
    * @dev This allow a contract to recover any ERC20 token received in a contract by transferring the balance to the contract owner.
    * This will prevent any accidental loss of tokens.
    */
    /**
     * @dev Reclaim all IERC20 compatible tokens
     * @param _token IERC20 The address of the token contract
     */
    function reclaimToken(IERC20 _token,uint256 amount) external onlyOwner {
        uint256 balance = _token.balanceOf(address(this));
        if (amount<=balance){
            _token.safeTransfer(owner(), amount);
        }
    }
    
    uint256[49] private __gap;
} 
