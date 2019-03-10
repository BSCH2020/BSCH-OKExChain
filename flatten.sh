#!/bin/bash

# truffle-flattener contracts-bsc/deprecatedFarmWithApi.sol > ./flattenered/FarmWithApi.sol
# truffle-flattener contracts-bsc/BSCH.sol > ./flattenered/BSCH.sol
# truffle-flattener contracts-bsc/ETHST.sol > ./flattenered/ETHST.sol
truffle-flattener contracts-bsc/tau/bridge/maya/BscMayaBridge.sol > ./flattenered/BscMayaBridge.sol

sed -i 's/SPDX-License-Identifier:\ MIT/license/' flattenered/BscMayaBridge.sol
sed -i 's/pragma\ experimental\ ABIEncoderV2;/\/\/abiv2/' flattenered/BscMayaBridge.sol
echo "pragma experimental ABIEncoderV2;\n" >> flattenered/BscMayaBridge.sol
