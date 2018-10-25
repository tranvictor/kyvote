const KyVote = artifacts.require("KyVote");
const BigNumber = require('bignumber.js');
const Web3 = require('web3');

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
      var optionNames = [web3.fromAscii("option1"), web3.fromAscii("\n"), web3.fromAscii("option2"), web3.fromAscii("\n")];
      console.log(web3.fromAscii("New") + " " + web3.fromAscii("Campaign"));
      console.log(web3.fromAscii("option1") + " " + web3.fromAscii("\n"));
      console.log(web3.fromAscii("url1") + " " + web3.fromAscii("\n"));
      var optionURLs = [web3.fromAscii("url1"), web3.fromAscii("\n"), web3.fromAscii("url2"), web3.fromAscii("\n")];
      return kyVote.createCampaign([web3.fromAscii("New"), web3.fromAscii("campaign")], optionNames, optionURLs, 999999999999, true, [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: "+ campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      return kyVote.getCampaignDetails(campaignID);
    }).then(function(details) {
      assert.equal(details[1].length, 2, "Title should have 2 bytes32 data");
      assert.equal(details[2], 999999999999, "Ending time should be set to default value");
      assert.equal(details[3], accounts[0], "Admin should be the sender of create campaign");
      assert.equal(details[4], true, "The campaign should allow multiple choices");
      return kyVote.getOptionsCount(parseInt(BigNumber(details[0])));
    }).then(function(data) {
      assert.equal(parseInt(BigNumber(data)), 2, "The number of options should be 2");
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
      var optionNames = [web3.fromAscii("option1"), web3.fromAscii("\n"), web3.fromAscii("option2"), web3.fromAscii("\n")];
      var optionURLs = [web3.fromAscii("url1"), web3.fromAscii("\n"), web3.fromAscii("url2"), web3.fromAscii("\n")];
      return kyVote.createCampaign([web3.fromAscii("New"), web3.fromAscii("campaign")], optionNames, optionURLs, 999999999999, true, [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
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
      var optionNames = [web3.fromAscii("option1"), web3.fromAscii("\n"), web3.fromAscii("option2"), web3.fromAscii("\n")];
      var optionURLs = [web3.fromAscii("url1"), web3.fromAscii("\n"), web3.fromAscii("url2"), web3.fromAscii("\n")];
      return kyVote.createCampaign([web3.fromAscii("New"), web3.fromAscii("campaign")], optionNames, optionURLs, 999999999999, true, [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      //console.log("Created new campaign with ID: "+ campaignID);
      return kyVote.getListOptions(campaignID);
      //console.log("Created new campaign with ID: "+ campaignID);
    }).then(function(details) {
      assert.equal(details.length, 3, "Should return 3 arrays");
      assert.equal(details[0].length, 2, "Should return 2 elements in option ids");
      assert.equal(details[1].length, 4, "Should return 4 elements in option names");
      assert.equal(details[2].length, 4, "Should return 4 elements in option urls");
      let id0 = parseInt(BigNumber(details[0][0]));
      let id1 = parseInt(BigNumber(details[0][1]));
      assert.equal(id0, 0, "First option should have id 0");
      assert.equal(id1, 1, "Second option should have id 1");
      return kyVote.getOption(campaignID, 0);
    }).then(function(option0Details) {
      assert.equal(option0Details.length, 4, "Should return 4 data for option 0");
      assert.equal(0, parseInt(BigNumber(option0Details[0])), "First element should be id with value 0");
      assert.equal(option0Details[3].length, 0, "Should have no voters for option 0");
      return kyVote.getOption(campaignID, 1);
    }).then(function(option1Details) {
      assert.equal(option1Details.length, 4, "Should return 4 data for option 1");
      assert.equal(1, parseInt(BigNumber(option1Details[0])), "First element should be id with value 1");
      assert.equal(option1Details[3].length, 0, "Should have no voters for option 1");
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(isWhitelisted) {
      assert.equal(isWhitelisted, true, "Account 0 should be whitelisted for this campaign");
      return kyVote.getVoters(campaignID, 0);
    }).then(function(voters0) {
      assert.equal(voters0.length, 0, "Should have no voters for option 0");
      return kyVote.getVoters(campaignID, 1);
    }).then(function(voters1) {
      assert.equal(voters1.length, 0, "Should have no voters for option 1");
    });
  });
  it("Test add new whitelisted addresses", function() {
    var kyVote;
    var campaginID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      var optionNames = [web3.fromAscii("option1"), web3.fromAscii("\n"), web3.fromAscii("option2"), web3.fromAscii("\n")];
      var optionURLs = [web3.fromAscii("url1"), web3.fromAscii("\n"), web3.fromAscii("url2"), web3.fromAscii("\n")];
      return kyVote.createCampaign([web3.fromAscii("New"), web3.fromAscii("campaign")], optionNames, optionURLs, 999999999999, true, [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: " + campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "The account 0 should be in the whitelisted addresses");
      kyVote.updateWhitelistedAddresses(campaignID, [0x2262d4f6312805851e3b27c40db2c7282e6e4a49], true);
      return kyVote.checkWhitelisted(campaignID, 0x2262d4f6312805851e3b27c40db2c7282e6e4a49);
    }).then(function(whitelisted) {
      //console.log("Override whitelisted addresses with empty data");
      assert.equal(whitelisted, true, "0x2262d4f6312805851e3b27c40db2c7282e6e4a49 should be added into the whitelisted addresses");
    });
  });
  it("Test remove whitelisted addresses", function() {
    var kyVote;
    var campaginID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      var optionNames = [web3.fromAscii("option1"), web3.fromAscii("\n"), web3.fromAscii("option2"), web3.fromAscii("\n")];
      var optionURLs = [web3.fromAscii("url1"), web3.fromAscii("\n"), web3.fromAscii("url2"), web3.fromAscii("\n")];
      return kyVote.createCampaign([web3.fromAscii("New"), web3.fromAscii("campaign")], optionNames, optionURLs, 999999999999, true, [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: " + campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "The account 0 should be in the whitelisted addresses");
      kyVote.updateWhitelistedAddresses(campaignID, [0x2262d4f6312805851e3b27c40db2c7282e6e4a49], false);
      // remove non whitelisted address
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "The account 0 should be in the whitelisted addresses");
      kyVote.updateWhitelistedAddresses(campaignID, [accounts[0]], false);
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
      var optionNames = [web3.fromAscii("option1"), web3.fromAscii("\n"), web3.fromAscii("option2"), web3.fromAscii("\n")];
      var optionURLs = [web3.fromAscii("url1"), web3.fromAscii("\n"), web3.fromAscii("url2"), web3.fromAscii("\n")];
      return kyVote.createCampaign([web3.fromAscii("New"), web3.fromAscii("campaign")], optionNames, optionURLs, 999999999999, true, [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: "+ campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      //console.log("Voting option 0");
      kyVote.vote(campaignID, [0], {from: accounts[0]});
      return kyVote.getVoters(campaignID, 0);
    }).then(function(voters0) {
      assert.equal(voters0.length, 1, "Should have 1 voter for option 0");
      assert.equal(voters0[0], accounts[0], "Voter of option 0 should be account 0");
      kyVote.updateWhitelistedAddresses(campaignID, [accounts[0]], false);
      //console.log("Removed account 0 from whitelisted address");
      return kyVote.getVoters(campaignID, 0);
    }).then(function(voters0) {
      assert.equal(voters0.length, 0, "Account 0 should be removed from option 0 voters as it is not a whitelisted address anymore");
    });
  });
  it("Test add new whitelisted addresses", function() {
    var kyVote;
    var campaginID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      var optionNames = [web3.fromAscii("option1"), web3.fromAscii("\n"), web3.fromAscii("option2"), web3.fromAscii("\n")];
      var optionURLs = [web3.fromAscii("url1"), web3.fromAscii("\n"), web3.fromAscii("url2"), web3.fromAscii("\n")];
      return kyVote.createCampaign([web3.fromAscii("New"), web3.fromAscii("campaign")], optionNames, optionURLs, 999999999999, true, [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: " + campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      return kyVote.checkWhitelisted(campaignID, accounts[0]);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "The account 0 should be in the whitelisted addresses");
      return kyVote.checkWhitelisted(campaignID, 0x2262d4f6312805851e3b27c40db2c7282e6e4a49);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, false, "0x2262d4f6312805851e3b27c40db2c7282e6e4a49 should be in the whitelisted addresses");
      kyVote.updateWhitelistedAddresses(campaignID, [0x2262d4f6312805851e3b27c40db2c7282e6e4a49], true);
      //console.log("Added 0x2262d4f6312805851e3b27c40db2c7282e6e4a49 to whitelisted addresses");
      return kyVote.checkWhitelisted(campaignID, 0x2262d4f6312805851e3b27c40db2c7282e6e4a49);
    }).then(function(whitelisted) {
      assert.equal(whitelisted, true, "0x2262d4f6312805851e3b27c40db2c7282e6e4a49 should be in the whitelisted addresses");
    });
  });
  it("Test whitelisted account should be able to vote and unvote for all options", function() {
    var kyVote;
    var campaignID;
    return KyVote.deployed().then(function(instance) {
      kyVote = instance;
      var optionNames = [web3.fromAscii("option1"), web3.fromAscii("\n"), web3.fromAscii("option2"), web3.fromAscii("\n")];
      var optionURLs = [web3.fromAscii("url1"), web3.fromAscii("\n"), web3.fromAscii("url2"), web3.fromAscii("\n")];
      return kyVote.createCampaign([web3.fromAscii("New"), web3.fromAscii("campaign")], optionNames, optionURLs, 999999999999, true, [accounts[0]]);
    }).then(function(transaction) {
      numberCampaigns++;
      //console.log(transaction.logs[0].args);
      campaignID = parseInt(BigNumber(transaction.logs[0].args.campaignID));
      //console.log("Created new campaign with ID: "+ campaignID);
      assert.equal(campaignID, numberCampaigns - 1, "Invalid campaign ID");
      //console.log("Voting option 0");
      kyVote.vote(campaignID, [0], {from: accounts[0]});
      return kyVote.getVoters(campaignID, 0);
    }).then(function(voters0) {
      //console.log("Voted option 0");
      assert.equal(voters0.length, 1, "Should have 1 voter for option 0");
      assert.equal(voters0[0], accounts[0], "Voter of option 0 should be account 0");
      //console.log("Unvoting option 0");
      kyVote.vote(campaignID, [], {from: accounts[0]});
      return kyVote.getVoters(campaignID, 0);
    }).then(function(voters0) {
      //console.log("Unvoted option 0");
      assert.equal(voters0.length, 0, "Should have no voter for option 0");
      return kyVote.getVoters(campaignID, 1);
    }).then(function(voters1) {
      assert.equal(voters1.length, 0, "Should have 0 voters for option 1");
      //console.log("Voting option 1");
      kyVote.vote(campaignID, [1], {from: accounts[0]});
      return kyVote.getVoters(campaignID, 1);
    }).then(function(voters1) {
      //console.log("Voted option 1");
      assert.equal(voters1.length, 1, "Should have 1 voter for option 1");
      //console.log("Unvoting option 1");
      kyVote.vote(campaignID, [], {from: accounts[0]});
      return kyVote.getVoters(campaignID, 1);
    }).then(function(voters1) {
      //console.log("Unvoted option 1");
      assert.equal(voters1.length, 0, "Should have 0 voters for option 1");
      //console.log("Voting multiple options");
      kyVote.vote(campaignID, [0, 1], {from: accounts[0]});
      return kyVote.getVoters(campaignID, 0);
    }).then(function(voters0) {
      //console.log("Voted option 0");
      assert.equal(voters0.length, 1, "Should have 1 voter for option 0");
      return kyVote.getVoters(campaignID, 1);
    }).then(function(voters1) {
      //console.log("Voted option 1");
      assert.equal(voters1.length, 1, "Should have 1 voter for option 1");
    });
  });
})
