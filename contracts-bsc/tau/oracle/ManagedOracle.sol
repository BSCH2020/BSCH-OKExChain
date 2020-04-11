// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../../libraries/UpgradeableBase.sol";
import "../../interfaces/IOracle.sol";
import "./MarketOracle.sol";

contract ManagedOracle is MarketOracle {
    using SafeMathUpgradeable for uint256;
    bool public useSwapData;
    bool public renouncedManagedRight;
    uint256 public currentData;
    uint256 public pendingData;
    bytes32 public constant ROLE_DATA_ADMIN = keccak256("ROLE_DATA_ADMIN");
    string public name;
    uint256 public bounceFactor;
    function initialize(string memory name_,uint256 initData_)public initializer{
        __MarketOracle_init_chained(address(0),address(0));
        name = name_;
        currentData = initData_;
        pendingData = initData_;
        bounceFactor = 1;
    }
    modifier _onlyDataAdmin{
        require(_msgSender() == owner() || hasRole(ROLE_DATA_ADMIN, _msgSender()));
        _;
    }
    modifier _onlyCanManage{
        require(!renouncedManagedRight);
        _;
    }
    function renounceManagedRight()public onlyOwner{
        useSwapData = true;
        renouncedManagedRight = true;
    }

    function setBounceFactor(uint256 factor) public _onlyDataAdmin{
        require(factor!=0);
        bounceFactor = factor;
    }

    function setUseSwapData(bool whether_)public _onlyDataAdmin _onlyCanManage{
        useSwapData = whether_;
    }

    function setPendingData(uint256 data)public _onlyDataAdmin{
        pendingData = data;
    }
    function setCurrentData(uint256 data)public _onlyDataAdmin{
        currentData = data;
    }

    function getData()override public view returns (uint256){
        if (useSwapData){
            return super.getData().div(bounceFactor);
        }
        return currentData.div(bounceFactor);
    }
    function update()override public onlyControllerOrOwner{
        super.update();
        if (!useSwapData){
            currentData = pendingData;
        }
    }

    function updateSwapData()public onlyControllerOrOwner{
        super.update();
    }

    function getSwapData()public view returns(uint256){
        return super.getData().div(bounceFactor);
    }
}
