//var HDWalletProvider = require("truffle-hdwallet-provider");

const gas = 6.5 * 1e6
const gasPrice = 2000000000 // 2 gwei

module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gas: 28 * 1e6,
      websockets: true
    },
    coverage: {
      host: 'localhost',
      port: 8555,
      network_id: '*',
      gas: 0xfffffffffff,
      gasPrice: 0x01,
      websockets: true
    },
    rinkebyIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 4,
      timeoutBlocks: 200,
      gas: gas,
      gasPrice: gasPrice,
      skipDryRun: true
    },
    rinkeby: {
      provider: function() { 
      //return new HDWalletProvider("fix subway blush enemy black reform invest van drive advance birth six", "https://rinkeby.infura.io/v3/d213b97a1c58420a8e8597dd0fbd864c");
      },
      network_id: 4,
      gas: 6500000,
      gasPrice: 10000000000,
      skypDryRun: true
    },
    mainIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 1,
      timeoutBlocks: 200,
      gas: gas,
      gasPrice: gasPrice,
      skipDryRun: true
    }
  },
  compilers: {
    solc: {
      version: '0.5.4',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
}

// const HDWalletProvider = require('truffle-hdwallet-provider');
// const infuraKey = "fj4jll3k.....";
//
// const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();

