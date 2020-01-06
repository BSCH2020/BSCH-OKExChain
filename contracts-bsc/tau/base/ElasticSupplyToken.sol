// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "./ElasticSupplyTokenBase.sol";


contract ElasticSupplyToken is ElasticSupplyTokenBase{
    using SafeMathInt for int256;
    using SafeMathUpgradeable for uint256;

    uint256 public constant MAX_INIT = uint256(~uint128(0)*2**32);//((2^128)-1)*2^32
    uint256 public constant MAX_SUPPLY = ~uint128(0);  // (2^128) - 1


    address public monetaryPolicy;
    uint256 public rebaseStartTime;

    uint256 public TOTAL_EXPANDED;
    bool public started;

    uint256 private _totalElasticSupply;
    uint256 private _balanceDivByFactor;
    
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event LogMonetaryPolicyUpdated(address monetaryPolicy);

    modifier onlyAfterRebaseStart() {
        require(now >= rebaseStartTime);
        _;
    }
    modifier validRecipient(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }
    modifier onlyMonetaryPolicy() {
        require(msg.sender == monetaryPolicy);
        _;
    }

    function initialize(string memory name, string memory symbol) public override virtual initializer {
        __ElasticSupplyToken_init_chained(name,symbol);
    }
    function __ElasticSupplyToken_init_chained(string memory name,string memory symbol) internal initializer{
        __ElasticSupplyTokenBase_init_chained(name,symbol);
        __ElasticSupplyToken_init_unchained();
    }
    function __ElasticSupplyToken_init_unchained() internal initializer{
        _pause();//first we pause our contract only start after our policy contract called our provide init supply method 
        started = false;
    }    

    function startWithInitialSupply(uint256 initialSupply,uint256 rebaseStartTime_) public onlyOwner{
        require(!started,"started");
        require(initialSupply>1,"initalSupply should >1");
        _unpause();
        rebaseStartTime = rebaseStartTime_;

        _totalElasticSupply = initialSupply;
        TOTAL_EXPANDED = MAX_INIT - (MAX_INIT % initialSupply);
        _balanceDivByFactor = TOTAL_EXPANDED.div(_totalElasticSupply);
        _mint(owner(), TOTAL_EXPANDED);
        started = true;
    }

    // authed method
    function setMonetaryPolicy(address plolicy) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),"have no right");
        monetaryPolicy = plolicy;
        emit LogMonetaryPolicyUpdated(plolicy);
    }

    function rebase(uint256 epoch,int256 supplyDelta) external 
        onlyMonetaryPolicy onlyAfterRebaseStart nonReentrant returns(uint256){
        if (supplyDelta ==0 ){
            emit LogRebase(epoch, _totalElasticSupply);
            return _totalElasticSupply;
        }
        if (supplyDelta<0){
            _totalElasticSupply = _totalElasticSupply.sub(uint256(supplyDelta.abs()));
        }else{
            _totalElasticSupply = _totalElasticSupply.add(uint256(supplyDelta));
        }
        if (_totalElasticSupply > MAX_SUPPLY){
            _totalElasticSupply = MAX_SUPPLY;
        }

        _balanceDivByFactor = TOTAL_EXPANDED.div(_totalElasticSupply);

        emit LogRebase(epoch, _totalElasticSupply);
        return _totalElasticSupply;
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
    function mint(address to, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have minter role to mint");
        require(amount<=_totalElasticSupply.mul(100),"require mint number < 100 * totalsupply");
        
        uint256 expanded = amount.mul(_balanceDivByFactor);
        _totalElasticSupply = _totalElasticSupply.add(amount);
        TOTAL_EXPANDED = TOTAL_EXPANDED.add(expanded);
        _mint(to, expanded);        
        emit Transfer(address(0), to, amount);
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalElasticSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account).div(_balanceDivByFactor);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override 
        validRecipient(recipient) returns (bool) {
        uint256 expanded = amount.mul(_balanceDivByFactor);
        _transfer(_msgSender(), recipient, expanded);

        emit Transfer(_msgSender(), recipient, amount);
        return true;
    }
    
    

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override
        validRecipient(recipient) returns (bool) {
        uint256 decreasedAllowance = allowance(sender, _msgSender()).sub(amount, "ERC20: transferFrom exceeds allowance");
        _approve(sender, _msgSender(), decreasedAllowance);

        uint256 expanded = amount.mul(_balanceDivByFactor);
        _transfer(sender, recipient, expanded);

        emit Transfer(sender,recipient,amount);
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        uint256 expanded = amount.mul(_balanceDivByFactor);
        _burn(_msgSender(), expanded);
        TOTAL_EXPANDED = TOTAL_EXPANDED.sub(expanded);
        _totalElasticSupply = _totalElasticSupply.sub(amount);
        emit Transfer(_msgSender(),address(0),amount);
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
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), decreasedAllowance);

        uint256 expanded = amount.mul(_balanceDivByFactor);
        _burn(account, expanded);
        TOTAL_EXPANDED = TOTAL_EXPANDED.sub(expanded);
        _totalElasticSupply = _totalElasticSupply.sub(amount);
        emit Transfer(account,address(0),amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal override virtual {
        super._beforeTokenTransfer(account, to, amount);
        uint lock = _lockMap[account];
        require(lock<10,"you are not allowed to move coins atm");
        lock = _lockMap[to];
        if (lock>=10){
            _totalSupplyLocked = _totalSupplyLocked.add(amount);
        }
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
    uint256[50] private __gap;
    /**
     * @dev statistic data total supply which was locked by compliance officer
     */
    uint256 private _totalSupplyLocked;
    event Lock(address indexed account,uint256 amount);
    event UnLock(address indexed account,uint256 amount);
    uint internal constant  _lockMagicNum = 16;
    uint internal constant  _unLockMagicNum = 0;
    /**
     * @dev store a lock map for compiance work whether allow one user to transfer his coins
     *
     */
    mapping (address => uint) private _lockMap;
}
