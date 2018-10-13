var HDWalletProvider = require("truffle-hdwallet-provider");
KEYS = "direct table sustain aunt market history paper eternal unaware online accident game"

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '5777' // Match any network id
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider(KEYS, "https://ropsten.infura.io/v3/475b0fd7e25e446d85237b9cb56d10b5")
      },
      network_id: 3,
      gas: 4000000      //make sure this gas allocation isn't over 4M, which is the max
    }
  }
}
