require('dotenv').config();

const HDWalletProvider = require("@truffle/hdwallet-provider");

const mnemonic = process.env.SECRET.trim();

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard BSC port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    testnet: {
      provider: () => new HDWalletProvider(mnemonic, `https://data-seed-prebsc-1-s1.binance.org:8545/`),
      network_id: 97,
      confirmations: 2,
      timeoutBlocks: 2000,
      networkCheckTimeout: 9999,
      skipDryRun: true
    },
    bsc: {
      provider: () => new HDWalletProvider(mnemonic, `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 2,
      timeoutBlocks: 2000,
      networkCheckTimeout: 5000,
      skipDryRun: true
    },
  },
  compilers: {
    solc: {
      version: '^0.7.5',
    },
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    bscscan: process.env.BSCSCAN_API.trim()
  }
};
