/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */
const Deasync = require('deasync');
const readline = require('readline');
const HDWalletProvider = require('@truffle/hdwallet-provider');
// const infuraKey = "fj4jll3k.....";
//
var NonceTrackerSubprovider = require("web3-provider-engine/subproviders/nonce-tracker");
const fs = require('fs');
const mnemonic = fs.readFileSync("./console/secret").toString().trim();
const BSCSCANAPIKEY = fs.readFileSync("./console/bsc_api_key").toString().trim();
const regeneratorRuntime = require("regenerator-runtime");
const LedgerWalletProvider = require('truffle-ledger-provider');
// const WalletConnectProvider = require('@walletconnect/truffle-provider').default
const WalletConnectProvider = require('./src/lib/web3-walletconnect-bsc-provider').default;

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
module.exports = {  
  contracts_directory:"./contracts-bsc",
  contracts_build_directory: "./build-bsc/contracts",
  migrations_directory:"./migrations-bsc",

  // contracts_directory:"./contracts-unlock",
  // contracts_build_directory: "./build-bsc/contracts-unlock",
  // migrations_directory:"./migrations-unlock",
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */
  plugins: [
    'truffle-plugin-verify',
    "truffle-contract-size"
  ],
  api_keys: {
    bscscan: BSCSCANAPIKEY
  },
  networks: {
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    develop:{
      port: 9545,            // Standard Ethereum port (default: none)
      defaultEtherBalance: 500,
      network_id: 2020,       // Any network (default: none)
    },
    dev: {
      host: "127.0.0.1",     // Localhost (default: none)
      //7545,9545
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
      // gas: 0x6691b7,
    },
    dev_bsc: {
      host: "bsc.chinaalex.com",     // Localhost (default: none)
      //7545,9545
      port: 9545,            // Standard Ethereum port (default: none)
      network_id: "9898",       // Any network (default: none)
      // gas: 0x6691b7,
    },
    dev_bsc_fork: {
      host: "127.0.0.1",     // Localhost (default: none)
      //7545,9545
      port: 9548,            // Standard Ethereum port (default: none)
      network_id: 1056,       // Any network (default: none)
      // gas: 6721975,
      gasPrice: 10*1e9, // Specified in Wei
      from:"0xAd3784cD071602d6c9c2980d8e0933466C3F0a0a"
    },
    ethmain:{
      networkCheckTimeout:30000000,
      provider: () => new HDWalletProvider(mnemonic, `https://mainnet.infura.io/v3/84bf00df575b4501b673748ceb629b78`),
      network_id: 1,
      gasPrice: 20*1e9, // Specified in Wei
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true,
      production: true,
      from:'0xAd3784cD071602d6c9c2980d8e0933466C3F0a0a'
    },
    bsc_testnet:{
      networkCheckTimeout:30000000,
      provider: function(){
        let wallet = new HDWalletProvider(mnemonic, `https://data-seed-prebsc-2-s2.binance.org:8545`);
        let nonceTracker = new NonceTrackerSubprovider();
        wallet.engine._providers.unshift(nonceTracker);
        nonceTracker.setEngine(wallet.engine);
        return wallet;
      },
      network_id: 97,
      gas: 400000,
      gasPrice: 10*1e9, // Specified in Wei
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true,
      production: true,
      from:"0x402e07E69651B8fe37AC637760D5A0D92E6a3999"
    },
    bsc_test:{
      networkCheckTimeout:600000,
      provider: function(){
        const ledgerOptions = {
          networkId: 97, // testnet
          path: "44'/60'/0'/0/0", // hdwallet derivation path;ledger default:"44'/60'/0'/0",44'/60'/0'/0/10;m/44'/60'/0'/0/
          askConfirm: false,
          accountsLength: 10,
          accountsOffset: 0
        };
        let wallet = new LedgerWalletProvider(ledgerOptions, `https://data-seed-prebsc-2-s2.binance.org:8545`);
        //let wallet = new HDWalletProvider(mnemonic, `https://data-seed-prebsc-2-s2.binance.org:8545`);
        // let nonceTracker = new NonceTrackerSubprovider();
        // wallet.engine._providers.unshift(nonceTracker);
        // nonceTracker.setEngine(wallet.engine);
        return wallet;
      },
      // gas: 6721975,
      gasPrice: 15*1e9, // Specified in Wei
      network_id: 97,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    bsc_mem:{
      //mnemonic only exists in memory in order to make it safer on server
      networkCheckTimeout:30000000,
      provider: function(){
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
        
        let wallet = new HDWalletProvider(inputMnemonic, `https://bsc-dataseed1.binance.org/`);
        let nonceTracker = new NonceTrackerSubprovider();
        wallet.engine._providers.unshift(nonceTracker);
        nonceTracker.setEngine(wallet.engine);
        return wallet;
      },
      network_id: 56,
      gas: 400000,
      gasPrice: 10*1e9, // Specified in Wei
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true,
      production: true,
      from:"0xCF761e34C95a20F190b5Affb48CA2b6b25D8C315"
    },
    bsc_upgrade:{
      networkCheckTimeout:900000000,
      provider: function(){
        let wallet = new HDWalletProvider(mnemonic, `https://bsc-dataseed1.binance.org/`);
        let nonceTracker = new NonceTrackerSubprovider();
        wallet.engine._providers.unshift(nonceTracker);
        nonceTracker.setEngine(wallet.engine);
        return wallet;
      },
      network_id: 56,
      // gas: 4000000000,
      gas: 182000,
      gasPrice: 10*1e9, // Specified in Wei
      confirmations: 1,
      timeoutBlocks: 200000,
      skipDryRun: true,
      production: true,
      from:"0x402e07E69651B8fe37AC637760D5A0D92E6a3999"
      // from:"0x631fc1ea2270e98fbd9d92658ece0f5a269aa161"
      // from:'0xAd3784cD071602d6c9c2980d8e0933466C3F0a0a'
    },
    bsc:{
      networkCheckTimeout:30000000,
      provider: function(){
        // let provider = new WalletConnectProvider({'rpcUrl':`https://bsc-dataseed1.binance.org/`,'chainId':56});
        const ledgerOptions = {
          networkId: 56, // testnet
          path: "44'/60'/0'/0/0", // hdwallet derivation path;ledger default:"44'/60'/0'/0",44'/60'/0'/0/10;m/44'/60'/0'/0/
          askConfirm: false,
          accountsLength: 10,
          accountsOffset: 0
        };
        let wallet = new LedgerWalletProvider(ledgerOptions, `https://bsc-dataseed1.binance.org/`);
        return wallet;
      },
      network_id: 56,
      // gas: 6721975,
      gas:5500000,
      // gas: 100000,
      gasPrice: 5*1e9, // Specified in Wei
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true,
      production: true,
      // from:"0x631fc1ea2270e98fbd9d92658ece0f5a269aa161"
      from:'0xAd3784cD071602d6c9c2980d8e0933466C3F0a0a'
    },
    bscConnect:{
      networkCheckTimeout:30000000,
      provider: function(){
        let provider = new WalletConnectProvider({'rpcUrl':`https://bsc-dataseed1.binance.org/`,'chainId':56});
        return provider;
      },
      network_id: 56,
      // gas: 67219750,
      gasPrice: 15*1e9, // Specified in Wei
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true,
      production: true,
      from:'0xCF761e34C95a20F190b5Affb48CA2b6b25D8C315'
    }
    // Another network with more advanced options...
    // advanced: {
    // port: 8777,             // Custom port
    // network_id: 1342,       // Custom network
    // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    // from: <address>,        // Account to send txs from (default: accounts[0])
    // websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // },
    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    // ropsten: {
    // provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/YOUR-PROJECT-ID`),
    // network_id: 3,       // Ropsten's id
    // gas: 5500000,        // Ropsten has a lower block limit than mainnet
    // confirmations: 2,    // # of confs to wait between deployments. (default: 0)
    // timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
    // skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    // },
    // Useful for private networks
    // private: {
    // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
    // network_id: 2111,   // This network is yours, in the cloud.
    // production: true    // Treats this network as if it was a public net. (default: false)
    // }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    enableTimeouts:false,
    timeout: 900000,
    useColors: true
  },

  // Configure your compilers
  compilers: {
    solc: {
      //0.4.24,0.5.0,0.6.12,0.5.3
      // version: "0.6.9",    // Fetch exact version from solc-bin (default: truffle's version)---V1
      version: "0.6.9",    // Fetch exact version from solc-bin (default: truffle's version)---V2
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
};
