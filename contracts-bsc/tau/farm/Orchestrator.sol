// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;


import "../../libraries/UpgradeableBase.sol";
import "../base/ESTPolicy.sol";

/**
 * @title Orchestrator
 * @notice The orchestrator is the main entry point for rebase operations. It coordinates the policy
 * actions with external consumers.
 */
contract Orchestrator is UpgradeableBase {
    event PolicyAdded(address policy);
    event PolicyRemoved(address policy);
    struct Transaction {
        bool enabled;
        address destination;
        bytes data;
    }
    struct RunPolicy{
        bool enabled;
        ESTPolicy run;
    }

    event TransactionFailed(address indexed destination, uint index, bytes data);

    // Stable ordering is not guaranteed.
    Transaction[] public transactions;

    RunPolicy[] public policy;

    function initialize() public override virtual initializer{
        super.initialize();
    }

    function addPolicy(address policy_) external onlyOwner{
        policy.push(RunPolicy({
            enabled:true,
            run:ESTPolicy(policy_)
        }));
    }
    function setPolicyEnable(uint256 i,bool _enable) external onlyOwner{
        policy[i].enabled = _enable;
    }

    function removePolicy(address policy_) external onlyOwner{
        for (uint256 i=0;i<policy.length;i++){
            if (address(policy[i].run) == policy_){
                if (i+1 != policy.length){
                    policy[i] = policy[policy.length-1];
                }
                policy.pop();
                emit PolicyRemoved(policy_);
                break;
            }
        }
    }

    /**
     * @notice Main entry point to initiate a rebase operation.
     *         The Orchestrator calls rebase on the policy and notifies downstream applications.
     *         Contracts are guarded from calling, to avoid flash loan attacks on liquidity
     *         providers.
     *         If a transaction in the transaction list reverts, it is swallowed and the remaining
     *         transactions are executed.
     */
    function rebase()
        external
    {
        //make contract can trigger
        //require(msg.sender == tx.origin);  // solhint-disable-line avoid-tx-origin

        for (uint i=0;i<policy.length;i++){
            if (policy[i].enabled && address(policy[i].run) !=address(0) ){
                policy[i].run.rebase();
            }
        }

        for (uint i = 0; i < transactions.length; i++) {
            Transaction storage t = transactions[i];
            if (t.enabled) {
                bool result =
                    externalCall(t.destination, t.data);
                if (!result) {
                    emit TransactionFailed(t.destination, i, t.data);
                    revert("Transaction Failed");
                }
            }
        }
    }

    /**
     * @notice Adds a transaction that gets called for a downstream receiver of rebases
     * @param destination Address of contract destination
     * @param data Transaction data payload
     */
    function addTransaction(address destination, bytes memory data)
        external
        onlyOwner
    {
        transactions.push(Transaction({
            enabled: true,
            destination: destination,
            data: data
        }));
    }

    /**
     * @param index Index of transaction to remove.
     *              Transaction ordering may have changed since adding.
     */
    function removeTransaction(uint index)
        external
        onlyOwner
    {
        require(index < transactions.length, "index out of bounds");

        if (index < transactions.length - 1) {
            transactions[index] = transactions[transactions.length - 1];
        }

        transactions.pop();
    }

    /**
     * @param index Index of transaction. Transaction ordering may have changed since adding.
     * @param enabled True for enabled, false for disabled.
     */
    function setTransactionEnabled(uint index, bool enabled)
        external
        onlyOwner
    {
        require(index < transactions.length, "index must be in range of stored tx list");
        transactions[index].enabled = enabled;
    }

    /**
     * @return Number of transactions, both enabled and disabled, in transactions list.
     */
    function transactionsSize()
        external
        view
        returns (uint256)
    {
        return transactions.length;
    }

    /**
     * @dev wrapper to call the encoded transactions on downstream consumers.
     * @param destination Address of destination contract.
     * @param data The encoded data payload.
     * @return True on success
     */
    function externalCall(address destination, bytes memory data)
        internal
        returns (bool)
    {
        bool result;
        assembly {  // solhint-disable-line no-inline-assembly
            // "Allocate" memory for output
            // (0x40 is where "free memory" pointer is stored by convention)
            let outputAddress := mload(0x40)

            // First 32 bytes are the padded length of data, so exclude that
            let dataAddress := add(data, 32)
                        
            result := call(
                // 34710 is the value that solidity is currently emitting
                // It includes callGas (700) + callVeryLow (3, to pay for SUB)
                // + callValueTransferGas (9000) + callNewAccountGas
                // (25000, in case the destination address does not exist and needs creating)
                sub(gas(),34710),


                destination,
                0, // transfer value in wei
                dataAddress,
                mload(data),  // Size of the input, in bytes. Stored in position 0 of the array.
                outputAddress,
                0  // Output is ignored, therefore the output size is zero
            )
        }
        return result;
    }

    uint256[50] private __gap;
}
