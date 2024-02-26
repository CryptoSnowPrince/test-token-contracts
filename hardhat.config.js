require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

// Config from environment
const mnemonicPhrase = process.env.MNEMONIC;
const privateKey = process.env.PRIVATE_KEY;
const mnemonicPassword = process.env.MNEMONIC_PASSWORD;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.7',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ]
  },
  defaultNetwork: "pulsetestnet",
  networks: {
    pulsemainnet: {
      url: 'https://rpc.pulsechain.com',
      accounts: {
        mnemonic: mnemonicPhrase,
        path: 'm/44\'/60\'/0\'/0',
        initialIndex: 0,
        count: 1,
        passphrase: mnemonicPassword,
      },
      gasPrice: 600000000000000,
      network_id: '*',
    },
    pulsetestnet: {
      url: 'https://rpc-testnet-pulsechain.g4mm4.io',
      accounts: {
        mnemonic: mnemonicPhrase,
        path: 'm/44\'/60\'/0\'/0',
        initialIndex: 0,
        count: 1,
        passphrase: mnemonicPassword,
      },
      network_id: '*',
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  mocha: {
    timeout: 0,
  },
  etherscan: {
    apiKey: {
      pulsemainnet: "0000000000000000000000000000000000",
      pulsetestnet: "0000000000000000000000000000000000",
    },
    customChains: [
      {
        network: "pulsemainnet",
        chainId: 369,
        urls: {
          apiURL: "https://scan.pulsechain.com/api",
          browserURL: "https://scan.pulsechain.com"
        }
      },
      {
        network: "pulsetestnet",
        chainId: 943,
        urls: {
          apiURL: "https://api.scan.v4.testnet.pulsechain.com/api",
          browserURL: "https://scan.v4.testnet.pulsechain.com"
        }
      },
    ]
  },
};
