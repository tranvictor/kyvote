const KyVote = artifacts.require("KyVote");
const bignum = require('bignum');
const Web3 = require('web3');

function mergeCampaignAndOptionIDs(campaignID, optionID) {
  return bignum(campaignID).shiftLeft(128).or(optionID).toString();
}

contract('KyVote', function(accounts) {
  if (typeof web3 !== 'undefined') {
    web3 = new Web3(web3.currentProvider);
  } else {
    web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:7545"));
  }
  var numberCampaigns = 0;
  it("Test check campaign details should be correct as used to create", function() {
    var kyVote;
    var campaignID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      return kyVote.createCampaign("New campaign", ["option 1", "option 2"], ["url 1", "url 2"], bignum(999999999999).shiftLeft(4).or(1).toString(), [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(bignum(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: "+ campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      return kyVote.getCampaignDetails(campaignID);
    }).then(function(details) {
      console.log(details);
      assert.equal(bignum(details[1]), 999999999999, "Ending time should be set to default value");
      assert.equal(details[2], accounts[0], "Admin should be the sender of create campaign");
      assert.equal(details[3], true, "The campaign should allow multiple choices");
      return kyVote.getOptionsCount(campaignID);
    }).then(function(data) {
      assert.equal(parseInt(bignum(data)), 2, "The number of options should be 2");
      return kyVote.isCampaignEnded(campaignID);
    }).then(function(isEnded) {
      assert.equal(isEnded, false, "The new campaign should not be ended");
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(isWhitelisted) {
      assert.equal(isWhitelisted, true, "Account 0 should be in the whitelisted addresses");
      return kyVote.getListActiveCampaignIDs();
    }).then(function(activeIDs) {
      assert.equal(activeIDs.length, 1, "Should have only 1 active campaigns");
      assert.equal(activeIDs[0], campaignID, "Campaign ID should be in the list active IDs");
    });
  });
  it("Test stop an active (new) campaign", function() {
    var kyVote;
    var campaginID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      return kyVote.createCampaign("New campaign", ["option 1", "option 2"], ["url 1", "url 2"], bignum(999999999999).shiftLeft(4).or(1).toString(), [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(bignum(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: " + campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      return kyVote.isCampaignEnded(campaignID);
    }).then(function(isEnded) {
      assert.equal(isEnded, false, "The campagin should not be ended");
      return kyVote.stopCampaign(campaignID);
    }).then(function() {
      //console.log("Stopped the campaign with ID: " + campaignID);
      return kyVote.isCampaignEnded(campaignID);
    }).then(function(isEnded) {
      assert.equal(isEnded, true, "The campagin should be ended");
    });
  });
  it("Test option details should be all correct", function() {
    var kyVote;
    var campaignID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      return kyVote.createCampaign("New campaign", ["option 1", "option 2"], ["url 1", "url 2"], bignum(999999999999).shiftLeft(4).or(1).toString(), [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(bignum(transaction.logs[0].args.campaignID));
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      //console.log("Created new campaign with ID: "+ campaignID);
      return kyVote.getListOptions(campaignID);
      //console.log("Created new campaign with ID: "+ campaignID);
    }).then(function(details) {
      assert.equal(details.length, 3, "Should return 3 arrays");
      assert.equal(details[0].length, 2, "Should have 2 options");
      assert.equal(details[1].length, 2, "Should have 2 options");
      assert.equal(details[2].length, 2, "Should have 2 options");
      let id0 = parseInt(bignum(details[0][0]));
      let id1 = parseInt(bignum(details[0][1]));
      assert.equal(id0, 0, "First option should have id 0");
      assert.equal(id1, 1, "Second option should have id 1");
      return kyVote.getOption(mergeCampaignAndOptionIDs(campaignID, 0));
    }).then(function(option0Details) {
      assert.equal(option0Details.length, 3, "Should return 3 data for option 0");
      assert.equal(option0Details[2].length, 0, "Should have no voters for option 0");
      return kyVote.getOption(mergeCampaignAndOptionIDs(campaignID, 1));
    }).then(function(option1Details) {
      assert.equal(option1Details.length, 3, "Should return 3 data for option 1");
      assert.equal(option1Details[2].length, 0, "Should have no voters for option 1");
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(isWhitelisted) {
      assert.equal(isWhitelisted, true, "Account 0 should be whitelisted for this campaign");
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 0));
    }).then(function(voters0) {
      assert.equal(voters0.length, 0, "Should have no voters for option 0");
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 1));
    }).then(function(voters1) {
      assert.equal(voters1.length, 0, "Should have no voters for option 1");
    });
  });
  it("Test add new whitelisted addresses", function() {
    var kyVote;
    var campaginID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      return kyVote.createCampaign("New campaign", ["option 1", "option 2"], ["url 1", "url 2"], bignum(999999999999).shiftLeft(4).or(1).toString(), [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(bignum(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: " + campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "The account 0 should be in the whitelisted addresses");
      return kyVote.checkWhitelisted(campaignID, 0x2262d4f6312805851e3b27c40db2c7282e6e4a49);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, false, "0x2262d4f6312805851e3b27c40db2c7282e6e4a49 should be in the whitelisted addresses");
      kyVote.updateWhitelistedAddresses(bignum(campaignID).shiftLeft(4).or(1).toString(), [0x2262d4f6312805851e3b27c40db2c7282e6e4a49]);
      //console.log("Added 0x2262d4f6312805851e3b27c40db2c7282e6e4a49 to whitelisted addresses");
      return kyVote.checkWhitelisted(campaignID, 0x2262d4f6312805851e3b27c40db2c7282e6e4a49);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "0x2262d4f6312805851e3b27c40db2c7282e6e4a49 should be in the whitelisted addresses");
    });
  });
  it("Test remove whitelisted addresses", function() {
    var kyVote;
    var campaginID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      return kyVote.createCampaign("New campaign", ["option 1", "option 2"], ["url 1", "url 2"], bignum(999999999999).shiftLeft(4).or(1).toString(), [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(bignum(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: " + campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "The account 0 should be in the whitelisted addresses");
      kyVote.updateWhitelistedAddresses(bignum(campaignID).shiftLeft(4).or(0).toString(), [0x2262d4f6312805851e3b27c40db2c7282e6e4a49]);
      // remove non whitelisted address
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "The account 0 should be in the whitelisted addresses");
      kyVote.updateWhitelistedAddresses(bignum(campaignID).shiftLeft(4).or(0).toString(), [accounts[0]]);
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(whitelisted) {
      //console.log("Removed account 0 from whitelisted addresses");
      assert.equal(whitelisted, false, "The account 0 should not be in the whitelisted addresses");
    });
  });
  it("Test remove whitelisted address that was used to vote", function() {
    var kyVote;
    var campaignID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      return kyVote.createCampaign("New campaign", ["option 1", "option 2"], ["url 1", "url 2"], bignum(999999999999).shiftLeft(4).or(1).toString(), [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(bignum(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: "+ campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      //console.log("Voting option 0");
      kyVote.vote(campaignID, [0], {from: accounts[0]});
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 0));
    }).then(function(voters0) {
      assert.equal(voters0.length, 1, "Should have 1 voter for option 0");
      assert.equal(voters0[0], accounts[0], "Voter of option 0 should be account 0");
      kyVote.updateWhitelistedAddresses(bignum(campaignID).shiftLeft(4).or(0).toString(), [accounts[0]]);
      //console.log("Removed account 0 from whitelisted address");
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 0));
    }).then(function(voters0) {
      assert.equal(voters0.length, 0, "Account 0 should be removed from option 0 voters as it is not a whitelisted address anymore");
    });
  });
  it("Test whitelisted account should be able to vote and unvote for all options", function() {
    var kyVote;
    var campaignID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      return kyVote.createCampaign("New campaign", ["option 1", "option 2"], ["url 1", "url 2"], bignum(999999999999).shiftLeft(4).or(1).toString(), [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(bignum(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: "+ campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      //console.log("Voting option 0");
      kyVote.vote(campaignID, [0], {from: accounts[0]});
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 0));
    }).then(function(voters0) {
      //console.log("Voted option 0");
      assert.equal(voters0.length, 1, "Should have 1 voter for option 0");
      assert.equal(voters0[0], accounts[0], "Voter of option 0 should be account 0");
      //console.log("Unvoting option 0");
      kyVote.vote(campaignID, [], {from: accounts[0]});
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 0));
    }).then(function(voters0) {
      //console.log("Unvoted option 0");
      assert.equal(voters0.length, 0, "Should have no voter for option 0");
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 1));
    }).then(function(voters1) {
      assert.equal(voters1.length, 0, "Should have 0 voters for option 1");
      //console.log("Voting option 1");
      kyVote.vote(campaignID, [1], {from: accounts[0]});
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 1));
    }).then(function(voters1) {
      //console.log("Voted option 1");
      assert.equal(voters1.length, 1, "Should have 1 voter for option 1");
      //console.log("Unvoting option 1");
      kyVote.vote(campaignID, [], {from: accounts[0]});
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 1));
    }).then(function(voters1) {
      //console.log("Unvoted option 1");
      assert.equal(voters1.length, 0, "Should have 0 voters for option 1");
      //console.log("Voting multiple options");
      kyVote.vote(campaignID, [0, 1], {from: accounts[0]});
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 0));
    }).then(function(voters0) {
      //console.log("Voted option 0");
      assert.equal(voters0.length, 1, "Should have 1 voter for option 0");
      return kyVote.getVoters(mergeCampaignAndOptionIDs(campaignID, 1));
    }).then(function(voters1) {
      //console.log("Voted option 1");
      assert.equal(voters1.length, 1, "Should have 1 voter for option 1");
    });
  });
})
