// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./LWhitelisted.sol";
import "../interfaces/IWhitelist.sol";

contract MerkleWhitelist is IWhitelist,UpgradeableBase{
    bytes32 public constant WHITE_LIST_ADMIN_ROLE = keccak256("WHITE_LIST_ADMIN_ROLE");

    bytes32 public merkleRoot;
    string public sourceUri;
    
    event UpdatedWhitelist(bytes32 root, string uri);

    function initialize() public override initializer {
        __UpgradeableBase_init();
        _setupRole(WHITE_LIST_ADMIN_ROLE, _msgSender());
    }

    function root() external view override(IWhitelist) returns (bytes32) {
        return merkleRoot;
    }

    function uri() external view override(IWhitelist) returns (string memory) {
        return sourceUri;
    }

    function whitelisted(address account, bytes32[] memory proof) public view override(IWhitelist) returns (bool) {
        
        // Need to include bytes1(0x00) in order to prevent pre-image attack.
        bytes32 leafHash = keccak256(abi.encodePacked(bytes1(0x00), account));
        return checkProof(merkleRoot, proof, leafHash);
    }

    function checkProof(bytes32 _root, bytes32[] memory _proof, bytes32 _leaf) pure internal returns (bool) {
        bytes32 computedHash = _leaf;

        for (uint256 i = 0; i < _proof.length; i++) {
            bytes32 proofElement = _proof[i];

            if (computedHash < proofElement) {
                computedHash = keccak256(abi.encodePacked(bytes1(0x01), computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(bytes1(0x01),proofElement, computedHash));
            }
        }

        return computedHash == _root;
    }

    function updateWhitelist(bytes32 root_, string memory uri_) public override(IWhitelist) {
        require(
            hasRole(WHITE_LIST_ADMIN_ROLE, _msgSender()),
            "require WHITE_LIST_ADMIN_ROLE right"
        );

        merkleRoot = root_;
        sourceUri = uri_;

        emit UpdatedWhitelist(merkleRoot, sourceUri);
    } 

}
