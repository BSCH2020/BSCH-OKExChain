// SPDX-License-Identifier: MIT
pragma solidity>=0.5.4;

import "./TokenBase.sol";
import "./math/SafeMath.sol";

contract PeggyToken is TokenBase{
    using SafeMath for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    event Lock(address indexed account,uint256 amount);
    event UnLock(address indexed account,uint256 amount);
    uint internal constant  _lockMagicNum = 16;
    uint internal constant  _unLockMagicNum = 0;
    /**
     * @dev store a lock map for compiance work whether allow one user to transfer his coins
     *
     */
    mapping (address => uint) private _lockMap;

    // Dev address.
    address public devaddr;
    
    /**
     * @dev statistic data total supply which was locked by compliance officer
     */
    uint256 private _totalSupplyLocked;

    string public icon;

    string public meta;
    /**
     * @dev sets 0 initials tokens, the owner, and the supplyController.
     * this serves as the constructor for the proxy but compiles to the
     * memory model of the Implementation contract.
     */
    function initialize(string memory name, string memory symbol, address owner) public  {
        require(!initialized, "already initialized");
        super.initialize(name,symbol);
        _setupRole(PAUSER_ROLE, owner);
        devaddr = owner;
        initialized = true;
    }

    function changeIcon(string memory value) public onlyOwner{
        icon = value;
    }
    function changeMeta(string memory value) public onlyOwner{
        meta = value;
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public  {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public  {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have minter role to mint");
        _mint(to, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to unpause");
        _unpause();
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wtf?");
        devaddr = _devaddr;
    }

    function lockAccount(address account) public onlyOwner {
        uint256 bal = balanceOf(account);
        _totalSupplyLocked = _totalSupplyLocked.add(bal);
        _lockMap[account] = _lockMagicNum;
        emit Lock(account,bal);
    }

    function unLockAccount(address account) public onlyOwner {
        uint256 bal = balanceOf(account);
        _totalSupplyLocked = _totalSupplyLocked.sub(bal,"bal>_totalSupplyLocked");
        _lockMap[account] = _unLockMagicNum;
        emit UnLock(account,bal);
    }
    /**
     * @dev check about the compliance lock
     *
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal override {
        require(!paused(), "ERC20Pausable: token transfer while paused");
        uint lock = _lockMap[account];
        require(lock<10,"you are not allowed to move coins atm");
        lock = _lockMap[to];
        if (lock>=10){
            _totalSupplyLocked = _totalSupplyLocked.add(amount);
        }
    }

}
