const Deasync = require('deasync');
const readline = require('readline');
const port = process.env.HOST_PORT || 9090

function askQuestion(query,callback) {
  const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
  });

  return new Promise(resolve => rl.question(query, ans => {
      rl.close();
      resolve(ans);
      if(callback){
        callback(ans);
      }
  }))
}

let inputMnemonic="";
let readEnd = false;
if (inputMnemonic==undefined || inputMnemonic.length==0){
    askQuestion("inputMnemonic:?",function(ans){
    readEnd = true;
    inputMnemonic = ans;
    });
    while(!readEnd){
        Deasync.sleep(100);
    }
    
    readline.cursorTo(process.stdin, 0, 0);
    readline.clearScreenDown(process.stdin);
    process.stdout.write("\u001b[3J\u001b[2J\u001b[1J");
    process.stdout.write('\033c');
    console.clear();
}
module.exports = {
  networks: {
    mainnet: {
      from: 'TS3sWuX4as8xyU6GjtJ4JwDfccdTSKpm4H',
      // Don't put your private key here:
      privateKey: inputMnemonic,
      /*
Create a .env file (it must be gitignored) containing something like

  export PRIVATE_KEY_MAINNET=4E7FECCB71207B867C495B51A9758B104B1D4422088A87F4978BE64636656243

Then, run the migration with:

  source .env && tronbox migrate --network mainnet

*/
      userFeePercentage: 100,
      feeLimit: 1e9,
      fullHost: 'https://api.trongrid.io',
      network_id: '1'
    },
    shasta: {
      from: 'TS3sWuX4as8xyU6GjtJ4JwDfccdTSKpm4H',
      privateKey: inputMnemonic,
      userFeePercentage: 100,
      feeLimit: 1e9,
      fullHost: 'https://api.shasta.trongrid.io',
      network_id: '2'
    },
    nile: {
      privateKey: process.env.PRIVATE_KEY_NILE,
      userFeePercentage: 100,
      feeLimit: 1e8,
      fullHost: 'https://api.nileex.io',
      network_id: '3'
    },
    development: {
      // For trontools/quickstart docker image
      privateKey: 'da146374a75310b9666e834ee4ad0866d6f4035967bfc76217c5a495fff9f0d0',
      userFeePercentage: 0,
      feeLimit: 1e8,
      fullHost: 'http://127.0.0.1:' + port,
      network_id: '9'
    },
    compilers: {
      solc: {
        //0.4.24,0.5.0,0.6.12,0.5.3
        // version: "0.6.9",    // Fetch exact version from solc-bin (default: truffle's version)---V1
        version: "0.6.0",    // Fetch exact version from solc-bin (default: truffle's version)---V2
        // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
        settings: {          // See the solidity docs for advice about optimization and evmVersion
          optimizer: {
              enabled: true,
              runs: 100//v1 100
          }
          //  ,evmVersion: "byzantium"
          }
        }
    }
  }
}
