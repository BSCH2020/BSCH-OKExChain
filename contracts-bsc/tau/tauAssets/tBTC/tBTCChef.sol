// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../farm/MasterChef.sol";

contract tBTCChef is MasterChef{
    uint256 private constant BSC_BLOCK_MINT_SECONDS = 3;
    uint256 private constant INIT_SUPPLY = 2100;
    uint256 private constant INIT_WEEKS = 8;
    function initialize()override public initializer{
        //remain 0.005 for syrup pool 10.5tBTC
        super.initialize("τBitcoin Master Chef",address(0),
            //total
            INIT_SUPPLY* 10 ** IMiningESTChefLib.DEFAULT_EST_DECIMAL,
            //0.55*2100 = 1155,mining supply
            INIT_SUPPLY*55 * 10 ** (IMiningESTChefLib.DEFAULT_EST_DECIMAL-2),
            INIT_WEEKS,
            BSC_BLOCK_MINT_SECONDS,
            //start block,init 0
            0,
            //0.44*2100 = 924//airdrop supply (840-10.5(initial minted)+10.5+84)
            INIT_SUPPLY*44 * 10 ** (IMiningESTChefLib.DEFAULT_EST_DECIMAL-2));
    }
}
