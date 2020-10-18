// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

interface IWhitelist {
    //views
    function root() external view returns (bytes32);
    function uri() external view returns (string memory);
    function whitelisted(address account,bytes32[] calldata proof) external view returns(bool);

    //mutative
    function updateWhitelist(bytes32 root,string memory uri) external;

}
