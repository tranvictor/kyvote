const KyVote = artifacts.require("KyVote");
const BigNumber = require('bignumber.js');

contract('KyVote', function(accounts) {
  it("Admin should be the sender of create campaign", function() {
    var kyVote;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      return kyVote.createCampaign("New campaign", ["option 1"], ["url 1"], 999999999999, "mikele", true);
    }).then(function(transaction) {
      let campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
      console.log("Created new campaign with ID: "+ campaignID);
      return kyVote.getCampaignDetails(campaignID);
    }).then(function(details) {
      assert.equal(details[4], accounts[0], "Admin should be the sender of create campaign");
    });
  });
})
