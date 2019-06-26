// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../../libraries/UpgradeableBase.sol";
import "../../interfaces/IMerkleDistributor.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/cryptography/MerkleProofUpgradeable.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../../interfaces/IBEP20WithMint.sol";

contract MerkleDistributorPolicy is UpgradeableBase,IMerkleDistributor{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bytes32 public merkleRoot;
    uint256 public withdrawBlock;
    address public withdrawAddress;
    bool public mintOneByOne;
    IBEP20WithMint public airDropToken;
    uint256 public merkleTotalAlreadyClaimed;
    uint256 public deployedBlock;
    mapping(address=>uint256) public merkleAlreadyClaimed;
    // This is a packed array of booleans.
    mapping(uint256 => uint256) internal claimedBitMap;
    uint256 public airDropCap;
    function initialize(bytes32 _merkleRoot, uint256 _withdrawBlock,address airDropToken_) public initializer{
        __merkleDistributorPolicy_init(_merkleRoot,_withdrawBlock,airDropToken_);
    }
    function __merkleDistributorPolicy_init(bytes32 _merkleRoot, uint256 _withdrawBlock,address airDropToken_) internal initializer{
        __UpgradeableBase_init();
        __merkleDistributorPolicy_init_unchained(_merkleRoot,_withdrawBlock,airDropToken_);
    }
    function __merkleDistributorPolicy_init_unchained(bytes32 _merkleRoot, uint256 _withdrawBlock,address airDropToken_) internal initializer {
        merkleRoot = _merkleRoot;
        withdrawBlock = _withdrawBlock;
        withdrawAddress = _msgSender();
        mintOneByOne = true;
        deployedBlock = block.number;
        airDropToken = IBEP20WithMint(airDropToken_);
    }
    function setAirDropToken(address token) public onlyOwner{
        airDropToken = IBEP20WithMint(token);
    }
    function setAirDropCap(uint256 cap_)public onlyOwner{
        airDropCap = cap_;
    }
    function updateMerkleRoot(bytes32 root)public onlyOwner{
        merkleRoot = root;
    }

    function setIsMintingOneByOne(bool _mint) public onlyOwner{
        mintOneByOne = _mint;
    }

    modifier underCap(uint256 claimAmount){
        require(claimAmount.add(merkleTotalAlreadyClaimed)<=airDropCap,"cap exceeds");
        _;
    }

    function isClaimed(uint256 index) public override view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }
    function isFullyClaimed(uint256 index,address user,uint256 fullAmount)override public view returns (bool){
        if (isClaimed(index) && merkleAlreadyClaimed[user]>=fullAmount){
            return true;
        }
        return false;
    }

    function _setClaimed(uint256 index) internal {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(
        uint256 index,
        address account,    
        uint256 fullAmount,
        uint256 claimAmount,
        bytes32[] calldata merkleProof
    ) public virtual override underCap(claimAmount){
        require(!isFullyClaimed(index,account,fullAmount), "BEP20 MerkleDistributor: Drop already fully claimed.");
        require(claimAmount<=fullAmount,"claimAmount<=fullAmount");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, fullAmount));
        require(MerkleProofUpgradeable.verify(merkleProof, merkleRoot, node), "Ditto BEP20 MerkleDistributor: Invalid proof.");

        // Mark it claimed and send the token.
        _setClaimed(index);
        if (mintOneByOne){
            //need airdrop token give mint right to this contract
            airDropToken.mint(address(this),claimAmount);
        }
        IERC20Upgradeable(address(airDropToken)).safeTransfer(account, claimAmount);
        merkleAlreadyClaimed[account] = merkleAlreadyClaimed[account].add(claimAmount);

        merkleTotalAlreadyClaimed = merkleTotalAlreadyClaimed.add(claimAmount);
        emit Claimed(index, account, claimAmount);
    }

    function adminWithdraw(uint256 amount) external onlyOwner{
        require(
            block.number >= withdrawBlock,
            'ClaimDistributor: Withdraw failed, cannot claim until after validBlocks diff'
        );
        uint256 bal = airDropToken.balanceOf(address(this));
        if (amount<=bal){
            IERC20Upgradeable(address(airDropToken))
            .safeTransfer(withdrawAddress, amount);
        }
    }
    uint256[50] private __gap;
}
