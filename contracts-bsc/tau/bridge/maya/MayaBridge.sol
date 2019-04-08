// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

import "../../../libraries/UpgradeableBase.sol";
import "../../../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../../../interfaces/IBEP20WithMint.sol";

contract MayaBridge is UpgradeableBase{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    enum STATUS{INIT,ARRIVED,ROLLEDBACK,COMMITED,WAIT_SELF_CLAIM}
    enum DEFAULT_NETWORK{LOCAL,BSC,TRON,ETH,DOT,EOS}
    enum TYPE{OUT,IN}
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant BRIDGE_EXEC_ROLE = keccak256("BRIDGE_EXEC_ROLE");
    struct LocalRecord{
        address localAddress;
        address localToken;
    }
    struct OtherSideRecord{
        string  otherSideAddress;
        string  otherSideToken;
        uint256 otherNetworkId;
        uint256 otherSideTxid;//stores otherside indexid+1
    }
    struct OtherSideWithAmountParam{
        uint256 otherNetworkId;
        uint256 otherSideTxid;//stores otherside indexid+1
        uint256 amount;
        uint256 bridgeFee;
    }
    struct BridgeRecord{
        uint256 recordType;
        LocalRecord localInfo;
        OtherSideRecord otherSideInfo;
        uint256 amount;
        uint256 status;
        address op;
        uint256 bridgeFee;
        uint256 cts;//created time
        uint256 uts;//updated time
    }

    BridgeRecord[] public records;
    //user=>localToken=>records-index
    mapping(address =>  mapping(address=>uint256[]) ) public userRecord;
    //user=>localToken=>otherside-index=>(records-index+1)
    mapping(address =>  mapping(address=>mapping(uint256=>uint256)) ) public bridgeInSearchMap;
    // mapping(bytes32 => uint256) public searchMapping;
    event BridgeLeave(address indexed  account,address indexed token,
            string otherSideAddress,string otherSideToken,uint256 amount,uint256 networkId);
    event BridgeBack(address indexed  account,address indexed token,
            string otherSideAddress,string otherSideToken,uint256 amount,uint256 networkId);            
    event RecordStatusChanged(uint256 index,uint256 status);
    struct BridgeTokenPair{
        uint256 networkId;
        string otherSideToken;
        bool exist;
        bool enable;
        uint256 leftAmount;
        uint256 commitedLeftAmount;
        uint256 backedAmount;
        string otherSideBridge;
        uint256 maxOtherSideTxid;//stores max otherside indexid+1
    }
    //localToken=>networkId=>BridgeTokenPair
    mapping(address => mapping(uint256 => BridgeTokenPair)) public bridgeTokenPair;
    uint256 public MAX_ADDRESS_LEN;
    bool public IS_SIDE_CHAIN;
    mapping(address => uint256) feeInfo;
    uint256 public DEFAULT_FEE_AMOUNT;
    address public devAddr;
    uint256 public BRIDGE_TIMEOUT_SECONDS;
    function initialize(bool sideChain)public initializer{
        super.initialize();
        _setupRole(BRIDGE_ROLE,_msgSender());
        _setupRole(BRIDGE_EXEC_ROLE,_msgSender());
        MAX_ADDRESS_LEN = 45;
        IS_SIDE_CHAIN = sideChain;
        DEFAULT_FEE_AMOUNT = 5*10**(18-5);//0.000005
        devAddr = _msgSender();
        BRIDGE_TIMEOUT_SECONDS = 86400;
    }
    modifier onlyBridgeAdmin{
        require(hasRole(BRIDGE_ROLE, _msgSender()), "should have bridge role");
        _;
    }
    modifier onlyBridgeExec{
        require(hasRole(BRIDGE_EXEC_ROLE, _msgSender()), "should have bridge exec role");
        _;
    }
    function getBridgeTokenPair(address local,
        uint256 otherNetworkId) public view returns(BridgeTokenPair memory){
        return bridgeTokenPair[local][otherNetworkId];
    }
    function getRecordsLen()public view returns(uint256){
        return records.length;
    }
    function getUserRecordLen(address account,address token)public view returns(uint256){
        return userRecord[account][token].length;
    }
    function getUserRecord(address account,address token,uint256 index)public view returns(BridgeRecord memory){
        uint256 recordIndex = userRecord[account][token][index];
        return records[recordIndex];
    }
    function changeTimeoutSeconds(uint256 seconds_)public onlyBridgeAdmin{
        BRIDGE_TIMEOUT_SECONDS = seconds_;
    }
    function setMaxAddrLen(uint256 len_)public onlyBridgeAdmin{
        MAX_ADDRESS_LEN=len_;
    }
    function setFeeAmount(address token,uint256 fee)public onlyBridgeAdmin{
        feeInfo[token] = fee;
    }
    function setDevAddr(address addr)public onlyBridgeAdmin{
        require(addr!=address(0),"can't be 0");
        devAddr = addr;
    }
    function addBridgeTokenPair(address local,
            uint256 otherNetworkId,string memory otherSideToken_,string memory otherSideBridge_) public onlyBridgeAdmin{
            bridgeTokenPair[local][otherNetworkId].networkId = otherNetworkId;
            bridgeTokenPair[local][otherNetworkId].otherSideToken = otherSideToken_;
            bridgeTokenPair[local][otherNetworkId].exist = true;
            bridgeTokenPair[local][otherNetworkId].enable = true;
            bridgeTokenPair[local][otherNetworkId].otherSideBridge = otherSideBridge_;
            setFeeAmount(local,DEFAULT_FEE_AMOUNT);
    }
    function changeBridgeTokenPairSettings(address local,
            uint256 otherNetworkId,bool enable_,string memory otherSideBridge_) public onlyBridgeAdmin{
        BridgeTokenPair memory pair  = bridgeTokenPair[local][otherNetworkId];
        if (pair.exist){
            bridgeTokenPair[local][otherNetworkId].enable = enable_;
            bridgeTokenPair[local][otherNetworkId].otherSideBridge = otherSideBridge_;
        }
    }

    function rollLeaveBack(uint256 index)public onlyBridgeExec{
        BridgeRecord memory rec = records[index];
        require(rec.status!= uint256(STATUS.COMMITED) && rec.status!= uint256(STATUS.ROLLEDBACK));
        LocalRecord memory local = rec.localInfo;
        require(rec.recordType == uint256(TYPE.OUT),"type should be out");

        if (IS_SIDE_CHAIN && rec.status==uint256(STATUS.ARRIVED)){
            //side chain and already arrived, we neeed mit the burned tokens
            IBEP20WithMint(address(local.localToken)).mint(address(this),rec.amount.sub(rec.bridgeFee));
        }   
        //main chain transfer back
        IERC20Upgradeable(address(local.localToken))
            .safeTransfer(address(local.localAddress),rec.amount.sub(rec.bridgeFee));
        records[index].status = uint256(STATUS.ROLLEDBACK);
        records[index].uts = now;
        records[index].op = _msgSender();            
        emit RecordStatusChanged(index,uint256(STATUS.ROLLEDBACK));
    }
    function changeOutStatus(uint256 index,uint256 status,uint256 otherSideTxid_)public onlyBridgeExec{
        BridgeRecord memory rec = records[index];
        if (rec.status == uint256(STATUS.INIT)){
            require(status == uint256(STATUS.ARRIVED) || status == uint256(STATUS.WAIT_SELF_CLAIM),"status check");
        }else if(rec.status == uint256(STATUS.ARRIVED)){
            require(status == uint256(STATUS.COMMITED) || status == uint256(STATUS.WAIT_SELF_CLAIM),"status check");
        }else{
            revert("WAIT_SELF_CLAIM,COMMITED,ROLLEDBACK won't be changed");
        }
        LocalRecord memory local = rec.localInfo;
        OtherSideRecord memory other = rec.otherSideInfo;
        BridgeTokenPair memory pair = getBridgeTokenPair(local.localToken,other.otherNetworkId);
        require(pair.enable,"pair not enabled");

        if (status == uint256(STATUS.ARRIVED)){
            if (IS_SIDE_CHAIN){
                IBEP20WithMint(address(local.localToken)).burn(rec.amount.sub(rec.bridgeFee));
            }
            __updateLeftAmount(local,other,rec.amount.sub(rec.bridgeFee),0);
            otherSideTxid_ = otherSideTxid_.add(1);
            records[index].otherSideInfo.otherSideTxid = otherSideTxid_;
            if (pair.maxOtherSideTxid < otherSideTxid_){
                bridgeTokenPair[local.localToken][other.otherNetworkId]
                    .maxOtherSideTxid = otherSideTxid_;
            }
        }
        if (status == uint256(STATUS.COMMITED)){
            __updateCommitedLeftAmount(local,other,rec.amount);
        }
        records[index].status = status;
        records[index].uts = now;
        records[index].op = _msgSender();
        emit RecordStatusChanged(index,status);
    }
    function batchChangeOutStatus(uint256[] memory index,uint256[] memory status,uint256[] memory otherSideTxids)public onlyBridgeExec{
        require(index.length == status.length,"pairing");
        for (uint256 ii=0;ii<index.length;ii++){
            if (ii<otherSideTxids.length){
                changeOutStatus(index[ii],status[ii],otherSideTxids[ii]);
            }else{
                changeOutStatus(index[ii],status[ii],0);
            }
        }
    }
    function claimOutBack(address account,uint256 index)public{
        BridgeRecord memory rec = records[index];
        if (now < rec.cts+BRIDGE_TIMEOUT_SECONDS){
            require(rec.status == uint256(STATUS.WAIT_SELF_CLAIM),"need WAIT_SELF_CLAIM status");
        }else{
            //in case our offline admin faces some problem,users can claim back fund after BRIDGE_TIMEOUT_SECONDS
            require(rec.status == uint256(STATUS.WAIT_SELF_CLAIM) || rec.status == uint256(STATUS.INIT),"need WAIT_SELF_CLAIM||INIT status");
        }
        require(address(rec.localInfo.localAddress)== account,"account not match");
        require(rec.recordType == uint256(TYPE.OUT),"type error");

        LocalRecord memory local = rec.localInfo;
        OtherSideRecord memory other = rec.otherSideInfo;

        uint256 remainAmount = rec.amount.sub(rec.bridgeFee);
        IERC20Upgradeable(address(local.localToken)).safeTransfer(address(account),remainAmount);
        __updateLeftAmount(local,other,0,remainAmount);
        rec.status = uint256(STATUS.ROLLEDBACK);
        emit RecordStatusChanged(index,uint256(STATUS.ROLLEDBACK));
    }

    function bridgeOut(address token,string memory otherSideAddress_,uint256 otherNetworkId,uint256 amount)public {
        address account = _msgSender();
        BridgeTokenPair memory pair = getBridgeTokenPair(token,otherNetworkId);
        if ( pair.networkId>0 && pair.enable ){
            __bridgeOut(
                LocalRecord({
                    localAddress:account,
                    localToken:token
                }),
                OtherSideRecord({
                    otherSideAddress:otherSideAddress_,
                    otherSideToken:pair.otherSideToken,
                    otherNetworkId:otherNetworkId,
                    otherSideTxid:0
                }),
                amount
            );
        }
    }
    function __bridgeOut(LocalRecord memory localSide,
                OtherSideRecord memory otherSide,
                uint256 amount_)internal{
        require(amount_>0,"amount > 0");
        require(bytes(otherSide.otherSideAddress).length<=MAX_ADDRESS_LEN,"to address too long");
        uint256 fee = feeInfo[localSide.localToken];
        require(amount_>fee,"amount below fee");
        IERC20Upgradeable(address(localSide.localToken))
            .safeTransferFrom(address(localSide.localAddress),address(this),amount_);
        IERC20Upgradeable(address(localSide.localToken)).safeTransfer(address(devAddr),fee);
        otherSide.otherSideTxid = 0;
        records.push(BridgeRecord({
            recordType:uint256(TYPE.OUT),
            localInfo:localSide,
            otherSideInfo:otherSide,
            amount:amount_,
            status:uint256(STATUS.INIT),
            op:address(0),
            bridgeFee:fee,
            cts:now,
            uts:now
        }));
        uint256 index = records.length-1;
        userRecord[localSide.localAddress][localSide.localToken].push(index);
        
        // bytes32 digest = keccak256(
        //     abi.encodePacked(
        //         '\x19\x01',
        //         DOMAIN_SEPARATOR,
        //         keccak256(abi.encode(TYPE.OUT,localSide,otherSide,index))
        //     )
        // );
        // searchMapping[digest] = index+1;
        emit BridgeLeave(localSide.localAddress,localSide.localToken,
            otherSide.otherSideAddress,otherSide.otherSideToken,
            amount_,otherSide.otherNetworkId);
    }

    function batchBridgeIn(LocalRecord[] memory localSides,
            OtherSideRecord[] memory otherSides,uint256[] memory amounts,uint256[] memory bridgeFees)public onlyBridgeExec{
        require(amounts.length == otherSides.length,"pairing");
        require(amounts.length == localSides.length,"pairing");
        require(amounts.length == bridgeFees.length,"pairing");

        for (uint256 ii=0;ii<amounts.length;ii++){
            LocalRecord memory localSide = localSides[ii];
            OtherSideRecord memory otherSide = otherSides[ii];
            uint256 amount = amounts[ii];
            uint256 bridgeFee = bridgeFees[ii];
            bridgeIn(localSide,otherSide,amount,bridgeFee);
        }
    }
    function bridgeInWith(LocalRecord memory localSide,
        OtherSideWithAmountParam memory otherSideParam,
        string  memory otherSideAddress,string  memory otherSideToken) public onlyBridgeExec{
        OtherSideRecord memory otherSide = OtherSideRecord({
            otherSideAddress:otherSideAddress,
            otherSideToken:otherSideToken,
            otherNetworkId:otherSideParam.otherNetworkId,
            otherSideTxid:otherSideParam.otherSideTxid//stores otherside indexid+1
        });
        BridgeTokenPair memory pair = 
            getBridgeTokenPair(localSide.localToken,otherSide.otherNetworkId);
        if ( pair.networkId>0 && pair.enable ){
            __bridgeIn(localSide,otherSide,otherSideParam.amount,otherSideParam.bridgeFee);
        }
    }
    function bridgeInWithPlain(LocalRecord memory localSide,
        uint256 otherNetworkId,uint256 otherSideTxid,uint256 amount,uint256 bridgeFee,
        string  memory otherSideAddress,string  memory otherSideToken) public onlyBridgeExec{
        OtherSideRecord memory otherSide = OtherSideRecord({
            otherSideAddress:otherSideAddress,
            otherSideToken:otherSideToken,
            otherNetworkId:otherNetworkId,
            otherSideTxid:otherSideTxid//stores otherside indexid+1
        });
        BridgeTokenPair memory pair = 
            getBridgeTokenPair(localSide.localToken,otherSide.otherNetworkId);
        if ( pair.networkId>0 && pair.enable ){
            __bridgeIn(localSide,otherSide,amount,bridgeFee);
        }
    }
    function bridgeIn(LocalRecord memory localSide,
            OtherSideRecord memory otherSide,
            uint256 amount,uint256 bridgeFee
            )public onlyBridgeExec{
        BridgeTokenPair memory pair = 
            getBridgeTokenPair(localSide.localToken,otherSide.otherNetworkId);
        if ( pair.networkId>0 && pair.enable ){
            __bridgeIn(localSide,otherSide,amount,bridgeFee);
        }
    }
    function __bridgeIn(LocalRecord memory localSide,
                OtherSideRecord memory otherSide,
                uint256 amount,uint256 bridgeFee
                )internal{
        require(amount>0,"amount > 0");
        require(amount>bridgeFee,"amount below fee");
        require(otherSide.otherSideTxid>0,"otherSideTxid = index+1 should >0");
        BridgeTokenPair memory pair = getBridgeTokenPair(localSide.localToken,otherSide.otherNetworkId);
        if (pair.maxOtherSideTxid < otherSide.otherSideTxid){
            bridgeTokenPair[localSide.localToken][otherSide.otherNetworkId]
                .maxOtherSideTxid = otherSide.otherSideTxid;
        }
        if (IS_SIDE_CHAIN){
            //side chain mint them
            //fee will be calculate on original out network,so just transfer/mint remain amount
            IBEP20WithMint(address(localSide.localToken))
                .mint(address(localSide.localAddress),
                amount.sub(bridgeFee));
        }else{
            //main chain
            //fee will be calculate on original out network,so just transfer/mint remain amount
            IERC20Upgradeable(address(localSide.localToken))
                .safeTransfer(address(localSide.localAddress),
                amount.sub(bridgeFee));
        }
        
        records.push(BridgeRecord({
            recordType:uint256(TYPE.IN),
            localInfo:localSide,
            otherSideInfo:otherSide,
            amount:amount,
            status:uint256(STATUS.COMMITED),
            op:_msgSender(),
            bridgeFee:bridgeFee,
            cts:now,
            uts:now
        }));
        __updateBackedAmount(localSide,otherSide,amount);
        uint256 index = records.length-1;
        userRecord[localSide.localAddress][localSide.localToken].push(index);

        // bytes32 digest = keccak256(
        //     abi.encodePacked(
        //         '\x19\x01',
        //         DOMAIN_SEPARATOR,
        //         keccak256(abi.encode(TYPE.IN,localSide,otherSide,otherSide.otherSideTxid))
        //     )
        // );
        // searchMapping[digest] = index+1;
        bridgeInSearchMap[localSide.localAddress][localSide.localToken][otherSide.otherSideTxid] = index+1;
        emit BridgeBack(localSide.localAddress,localSide.localToken,
            otherSide.otherSideAddress,otherSide.otherSideToken,
            amount,otherSide.otherNetworkId);
    }

    function getBridgeInIndexBy(LocalRecord memory localSide,
                OtherSideRecord memory otherSide)public view returns(uint256){
        require(otherSide.otherSideTxid>0,"otherSideTxid = index+1 should >0");
        return bridgeInSearchMap[localSide.localAddress][localSide.localToken][otherSide.otherSideTxid];
    }
    function getBridgeInBy(LocalRecord memory localSide,
                OtherSideRecord memory otherSide)public view returns(BridgeRecord memory){
        require(otherSide.otherSideTxid>0,"otherSideTxid = index+1 should >0");
        uint256 index = bridgeInSearchMap[localSide.localAddress][localSide.localToken][otherSide.otherSideTxid];
        if (index>0){
            return records[index-1];
        }
    }

    function __updateBackedAmount(LocalRecord memory local,OtherSideRecord memory other,uint256 amount)internal{
        bridgeTokenPair[local.localToken][other.otherNetworkId].backedAmount
             = bridgeTokenPair[local.localToken][other.otherNetworkId].backedAmount.add(amount);
    }

    function __updateLeftAmount(LocalRecord memory local,OtherSideRecord memory other,uint256 incAmount,uint256 decAmount)internal{
        bridgeTokenPair[local.localToken][other.otherNetworkId].leftAmount
             = bridgeTokenPair[local.localToken][other.otherNetworkId].leftAmount.add(incAmount).sub(decAmount);
    }

    function __updateCommitedLeftAmount(LocalRecord memory local,OtherSideRecord memory other,uint256 amount)internal{
        bridgeTokenPair[local.localToken][other.otherNetworkId].commitedLeftAmount
             = bridgeTokenPair[local.localToken][other.otherNetworkId].commitedLeftAmount.add(amount);
    }
    uint256[50] private __gap;
}
