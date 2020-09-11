// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
    // Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool);
    // Returns true if the index and address has been fully marked claimed.
    function isFullyClaimed(uint256 index,address user,uint256 fullAmount) external view returns (bool);

    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(uint256 index,address account,uint256 fullAmount,uint256 claimAmount,bytes32[] calldata merkleProof) external;

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 amount);
}
