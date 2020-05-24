#!/bin/bash

bsc_geth --config ./scripts/mainnet/config.toml --datadir ./node --pprofaddr 0.0.0.0 --metrics --pprof
