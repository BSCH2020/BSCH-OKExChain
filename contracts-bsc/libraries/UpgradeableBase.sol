// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../libraries/OwnableContract.sol";

contract UpgradeableBase is PausableUpgradeable, AccessControlUpgradeable,OwnableContract{
    bool public adminFeatRenounced;
    function initialize() public virtual initializer {
        __UpgradeableBase_init();
    }
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function __UpgradeableBase_init()internal initializer{
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __Pausable_init_unchained();
        __Ownable_init_unchained();

        __UpgradeableBase_init_unchained();
    }

    function __UpgradeableBase_init_unchained() internal initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(PAUSER_ROLE, _msgSender());
    }
    modifier needPauseRole() {
        require(hasRole(PAUSER_ROLE, _msgSender()), "UpgradeableBase: must have pauser role to do this");
        _;
    }
    modifier needAdminFeature(){
        require(!adminFeatRenounced,"admin feature closed forever!");
        _;
    }
    function renounceAdminFeature()external onlyOwner{
        adminFeatRenounced = true;
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
    function pause() public virtual needPauseRole {
        // require(hasRole(PAUSER_ROLE, _msgSender()), "UpgradeableBase: must have pauser role to pause");
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
    function unpause() public virtual needPauseRole {
        // require(hasRole(PAUSER_ROLE, _msgSender()), "UpgradeableBase: must have pauser role to unpause");
        _unpause();
    }
    function reclaimToken(IERC20Upgradeable _token) public override onlyOwner {
        revert();
    }

    uint256[50] private __gap;
}
