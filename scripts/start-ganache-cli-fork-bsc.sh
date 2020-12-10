#!/bin/bash
cp -f ./scripts/unknown-1156-init.json ./.openzeppelin/unknown-1156.json 

ganache-cli -p 9548 --db ./db/bsc_fork -v -k istanbul --chainId 1156 --unlock 0x8Bd446aD0710D04bF509A176D6373c7d2b76b5C1 --unlock 0x631fc1ea2270e98fbd9d92658ece0f5a269aa161 --networkId 1056 --fork https://bsc-dataseed1.binance.org/\
    --unlock 0xad3784cd071602d6c9c2980d8e0933466c3f0a0a\
    --unlock 0x6056ddc41d3A68D8900cf43982E4C7BA76b2a3D3\
    --unlock 0xCc712b703736E0864Fd2Cc8DEad6D302d0c92B17
