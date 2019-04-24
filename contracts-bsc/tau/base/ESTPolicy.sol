// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../../libraries/UpgradeableBase.sol";
import "../../libraries/SafeMathInt.sol";

import "./ElasticSupplyToken.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../../interfaces/IMiningESTChef.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "../../interfaces/IOracle.sol";

contract ESTPolicy is UpgradeableBase{
    using SafeMathUpgradeable for uint256;
    using SafeMathInt for int256;
    using SafeCastUpgradeable for uint256;

    // This module orchestrates the rebase execution and downstream notification.
    address public orchestrator;

    // Market oracle provides the token/btoken exchange rate as an 18 decimal fixed point number.
    // (eg) An oracle value of 1.5e18 it would mean 1 tauBTC is trading for 1.50 BTCB.
    IOracle public marketOracle;

    // If the current exchange rate is within this fractional distance from the target, no supply
    // update is performed. Fixed point number--same format as the rate.
    // (ie) abs(rate - targetRate) / targetRate < deviationThreshold, then no supply change.
    // DECIMALS Fixed point number.
    uint256 public deviationThreshold;
    // The rebase lag parameter, used to dampen the applied supply adjustment by 1 / rebaseLag
    // Check setRebaseLag comments for more details.
    // Natural number, no decimal places.
    uint256 public rebasePostiveLag;
    uint256 public rebaseNegativeLag;
    // More than this much time must pass between rebase operations.
    uint256 public minRebaseTimeIntervalSec;

    // Block timestamp of last rebase operation
    uint256 public lastRebaseTimestampSec;
    // The rebase window begins this many seconds into the minRebaseTimeInterval period.
    // For example if minRebaseTimeInterval is 24hrs, it represents the time of day in seconds.
    uint256 public rebaseWindowOffsetSec;
    // The length of the time window where a rebase operation is allowed to execute, in seconds.
    uint256 public rebaseWindowLengthSec;
    // The number of rebase cycles since inception
    uint256 public epoch;
    uint256 private constant DECIMALS = 18;
    
    // Both are 18 decimals fixed point numbers.
    uint256 private constant MAX_RATE = 10**6 * 10**DECIMALS;
    //hard cap
    uint256 public MAX_SUPPLY;
    bool public rebaseLocked; 
    ElasticSupplyToken public manToken;
    IMiningESTChef public miningChef;
    struct RebaseRecord{
        uint256 epoch;
        uint256 exchangeRate;
        int256  requestedSupplyAdjustment;
        uint256 timestampSec;
        uint256 newBalance;
    }
    RebaseRecord[] public rebaseRecords;

    event LogRebase(
        uint256 indexed epoch,
        uint256 exchangeRate,
        int256 requestedSupplyAdjustment,
        uint256 timestampSec
    );

    modifier onlyOrchestrator() {
        require(msg.sender == orchestrator);
        _;
    }
    function initialize(address esToken,address chef,uint256 capAmount) public virtual initializer{
        __ESTPolicy_init_chained(esToken,chef,capAmount);
    }
    function __ESTPolicy_init_chained(address esToken,address chef,uint256 capAmount) internal initializer{
        __UpgradeableBase_init();
        __ESTPolicy_init_unchained(esToken,chef,capAmount);
    }
    function __ESTPolicy_init_unchained(address esToken,address chef,uint256 capAmount) internal initializer{
        manToken = ElasticSupplyToken(esToken);
        miningChef = IMiningESTChef(chef);
        // deviationThreshold = 0.1e18 = 5e16
        deviationThreshold = 10 * 10 ** (DECIMALS-2);// +- %10 don't rebase

        rebasePostiveLag = 5;
        rebaseNegativeLag = 2;
        minRebaseTimeIntervalSec = 1 days;
        rebaseWindowOffsetSec = 12*60*60;  // 12:00AM UTC -> 8:00PM SGT
        rebaseWindowLengthSec = 1 hours;
        lastRebaseTimestampSec = 0;
        epoch = 0;
        MAX_SUPPLY = capAmount * 10** uint256(manToken.decimals());
    }
    function setMaxSupply(uint256 max_) public onlyOwner{
        MAX_SUPPLY = max_;
    }
    function getRebaseRecordsLen()public view returns(uint256){
        return rebaseRecords.length;
    }   
    function setRebaseLocked(bool _locked) external onlyOwner {
        rebaseLocked = _locked;
    }
    function setChefAddress(address _chef) external onlyOwner {
        miningChef = IMiningESTChef(_chef);
    }
    /**
     * @notice Sets the reference to the market oracle.
     * @param marketOracle_ The address of the market oracle contract.
     */
    function setMarketOracle(IOracle marketOracle_)external onlyOwner{
        marketOracle = marketOracle_;
    }
    /**
     * @notice Sets the reference to the orchestrator.
     * @param orchestrator_ The address of the orchestrator contract.
     */
    function setOrchestrator(address orchestrator_)external onlyOwner{
        orchestrator = orchestrator_;
    }
    /**
     * @notice Sets the deviation threshold fraction. If the exchange rate given by the market
     *         oracle is within this fractional distance from the targetRate, then no supply
     *         modifications are made. DECIMALS fixed point number.
     * @param deviationThreshold_ The new exchange rate threshold fraction.
     */
    function setDeviationThreshold(uint256 deviationThreshold_)external onlyOwner{
        deviationThreshold = deviationThreshold_;
    }
    /**
     * @notice Sets the rebase lag parameter.
               It is used to dampen the applied supply adjustment by 1 / rebaseLag
               If the rebase lag R, equals 1, the smallest value for R, then the full supply
               correction is applied on each rebase cycle.
               If it is greater than 1, then a correction of 1/R of is applied on each rebase.
     * @param rebaseLag_ The new rebase lag parameter.
     */
    function setRebasePostiveLag(uint256 rebaseLag_)external onlyOwner{
        require(rebaseLag_ > 0);
        rebasePostiveLag = rebaseLag_;
    }
    function setRebaseNegativeLag(uint256 rebaseLag_)external onlyOwner{
        require(rebaseLag_ > 0);
        rebaseNegativeLag = rebaseLag_;
    }
    /**
     * @notice Sets the parameters which control the timing and frequency of
     *         rebase operations.
     *         a) the minimum time period that must elapse between rebase cycles.
     *         b) the rebase window offset parameter.
     *         c) the rebase window length parameter.
     * @param minRebaseTimeIntervalSec_ More than this much time must pass between rebase
     *        operations, in seconds.
     * @param rebaseWindowOffsetSec_ The number of seconds from the beginning of
              the rebase interval, where the rebase window begins.
     * @param rebaseWindowLengthSec_ The length of the rebase window in seconds.
     */
    function setRebaseTimingParameters(uint256 minRebaseTimeIntervalSec_,uint256 rebaseWindowOffsetSec_,
        uint256 rebaseWindowLengthSec_)external onlyOwner{
        require(minRebaseTimeIntervalSec_ > 0);
        require(rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_);

        minRebaseTimeIntervalSec = minRebaseTimeIntervalSec_;
        rebaseWindowOffsetSec = rebaseWindowOffsetSec_;
        rebaseWindowLengthSec = rebaseWindowLengthSec_;
    }

    /**
     * @return If the latest block timestamp is within the rebase time window it, returns true.
     *         Otherwise, returns false.
     */
    function inRebaseWindow() public view returns (bool) {
        return (
            now.mod(minRebaseTimeIntervalSec) >= rebaseWindowOffsetSec &&
            now.mod(minRebaseTimeIntervalSec) < (rebaseWindowOffsetSec.add(rebaseWindowLengthSec))
        );
    }

    /**
     * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
     *
     */
    function rebase() external onlyOrchestrator whenNotPaused{
        require(inRebaseWindow(),"not in allowed time");
        // This comparison also ensures there is no reentrancy.
        require((!rebaseLocked) && lastRebaseTimestampSec.add(minRebaseTimeIntervalSec) < now,"locked or time not allow");
        // Snap the rebase time to the start of this window.
        lastRebaseTimestampSec = now.sub(
            now.mod(minRebaseTimeIntervalSec)).add(rebaseWindowOffsetSec);
        
        epoch = epoch.add(1);

        (uint256 exchangeRate, uint256 targetRate, int256 supplyDelta) = getRebaseValues();
        uint256 supplyAfterRebase;
        if (supplyDelta<0){
            supplyAfterRebase = manToken.rebase(epoch,supplyDelta);
            if (address(miningChef)!=address(0)){
                miningChef.shrinkNoticedByPolicy(uint256(supplyDelta.abs()), supplyAfterRebase);
            }
        }else if (supplyDelta>0){
            //mint supplyDelta for period
            if (address(miningChef)!=address(0)){
                miningChef.mintMoreDelta(uint256(supplyDelta),minRebaseTimeIntervalSec);
                supplyAfterRebase = manToken.totalSupply();
            }
        }else{
            supplyAfterRebase = manToken.totalSupply();
        }

        assert(supplyAfterRebase <= MAX_SUPPLY);
        marketOracle.update();
        rebaseRecords.push(RebaseRecord({
            epoch :epoch.sub(1),
            exchangeRate:exchangeRate,
            requestedSupplyAdjustment:supplyDelta,
            timestampSec:now,
            newBalance:supplyAfterRebase
        }));
        emit LogRebase(epoch, exchangeRate, supplyDelta, now);
    }

    /**
     * @notice Calculates the supplyDelta and returns the current set of values for the rebase
     *
     * @dev The supply adjustment equals (_totalSupply * DeviationFromTargetRate) / rebaseLag
     *      Where DeviationFromTargetRate is (MarketOracleRate - targetRate) / targetRate
     * 
     */    
    function getRebaseValues() public view returns (uint256, uint256, int256) {
        //make our token's price closer to 1
        uint256 targetRate = 1* 10** DECIMALS;
        uint256 exchangeRate = marketOracle.getData();

        if (exchangeRate > MAX_RATE) {
            exchangeRate = MAX_RATE;
        }

        int256 supplyDelta = computeSupplyDelta(exchangeRate, targetRate);

        // Apply the dampening factor.
        if (supplyDelta < 0) {
            supplyDelta = supplyDelta.div(rebaseNegativeLag.toInt256());
        } else {
            supplyDelta = supplyDelta.div(rebasePostiveLag.toInt256());
        }

        if (supplyDelta > 0 && manToken.totalSupply().add(uint256(supplyDelta)) > MAX_SUPPLY) {
            supplyDelta = (MAX_SUPPLY.sub(manToken.totalSupply())).toInt256();
        }
        return (exchangeRate, targetRate, supplyDelta);
    }
    /**
     * @return Computes the total supply adjustment in response to the exchange rate
     *         and the targetRate.
     */
    function computeSupplyDelta(uint256 rate, uint256 targetRate)internal view returns (int256){
        if (withinDeviationThreshold(rate, targetRate)) {
            return 0;
        }
        // supplyDelta = totalSupply * (rate - targetRate) / targetRate
        int256 targetRateSigned = targetRate.toInt256();
        return manToken.totalSupply().toInt256()
            .mul(rate.toInt256().sub(targetRateSigned))
            .div(targetRateSigned);
    }

    /**
     * @param rate The current exchange rate, an 18 decimal fixed point number.
     * @param targetRate The target exchange rate, an 18 decimal fixed point number.
     * @return If the rate is within the deviation threshold from the target rate, returns true.
     *         Otherwise, returns false.
     */
    function withinDeviationThreshold(uint256 rate, uint256 targetRate)internal view returns (bool){
        uint256 absoluteDeviationThreshold = targetRate.mul(deviationThreshold)
            .div(10 ** DECIMALS);

        return (rate >= targetRate && rate.sub(targetRate) < absoluteDeviationThreshold)
            || (rate < targetRate && targetRate.sub(rate) < absoluteDeviationThreshold);
    }

    uint256[50] private __gap;
}
