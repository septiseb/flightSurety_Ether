var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "milk flash celery sample team horror trick pigeon okay giant consider tornado";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: '*',
      gas: 99999999999
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};