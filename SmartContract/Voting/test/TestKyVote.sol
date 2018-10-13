pragma solidity ^0.4.18;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/KyVote.sol";

contract TestKyVote {

  // Test create a new campaign, check if number campaign increased
  // details data of campaign are correct as original
  // and number of options and option data are correct as well
  function testCreateNewCampaign() public {
    KyVote kyVote = KyVote(DeployedAddresses.KyVote());
    // get current number of campaigns to check if number of campaigns increased after created new one
    uint numberCampaigns = kyVote.getTotalNumberCampaigns();
    // Set up some data for the campaigns with list of option names, urls
    bytes32[] memory names = new bytes32[](2);
    names[0] = bytes32("option 1");
    names[1] = bytes32("option 2");
    // endTime is set to be very large: 999999999999
    kyVote.createCampaign(bytes32("New campaign"), names, names, 999999999999, bytes32("mikele"), true);

    Assert.equal(kyVote.isCampaignEnded(numberCampaigns), false, "Campaign should be active");
    // Test number of options
    Assert.equal(kyVote.getOptionsCount(numberCampaigns), 2, "Number options is not correct");
    // Test campaign details
    (uint cID, bytes32 cName, uint cEndTime, bytes32 cCreatorID, address cAdmin, bool cMultipleChoice) = kyVote.getCampaignDetails(numberCampaigns);
    Assert.equal(numberCampaigns, cID, "Wrongly getting campaign");
    Assert.equal(cName, bytes32("New campaign"), "Name of campaign is not equal");
    Assert.equal(cEndTime, 999999999999, "End time of campaign is not equal");
    Assert.equal(cCreatorID, bytes32("mikele"), "Creator ID is not equal");
    Assert.equal(cMultipleChoice, true, "Campaign should be a multiple choice");
    Assert.equal(kyVote.getTotalNumberCampaigns(), numberCampaigns + 1, "Number campaign should be increased by one after created a new campaign");

    // Test option 0 data
    (uint oID, bytes32 oName, bytes32 oUrl, bytes32[] memory oVoterIDs) = kyVote.getOption(numberCampaigns, 0);
    Assert.equal(oID, 0, "Wrong getting option");
    Assert.equal(oName, names[0], "Name of option is not correct set");
    Assert.equal(oUrl, names[0], "URL of option is not correct set");
    Assert.equal(oVoterIDs.length, 0, "New campaign all options should have 0 voters");
  }

  // Test create new campaign becomes running
  function testNewCampaignShouldBeInActiveList() public {
    KyVote kyVote = KyVote(DeployedAddresses.KyVote());
    testCreateNewCampaign();
    uint numberCampaigns = kyVote.getTotalNumberCampaigns();
    uint[] memory campaignIDs = kyVote.getListActiveCampaignIDs();
    bool hasLastCampaign = false;
    for(uint i = 0; i < campaignIDs.length; i++) {
      if (campaignIDs[i] == numberCampaigns - 1) {
        hasLastCampaign = true;
      }
    }
    Assert.equal(hasLastCampaign, true, "List active campaigns should contain the new created campaign");
  }

  // Test create campaign check list options details
  function testCreateCampaignCheckListOptionsDetails() public {
    KyVote kyVote = KyVote(DeployedAddresses.KyVote());
    testCreateNewCampaign();
    (uint[] memory ids, bytes32[] memory names, bytes32[] memory urls) = kyVote.getListOptions(kyVote.getTotalNumberCampaigns() - 1);
    Assert.equal(ids.length, 2, "Should have exactly 2 options");
    Assert.equal(names.length, 2, "Should have exactly 2 options");
    Assert.equal(urls.length, 2, "Should have exactly 2 options");
    Assert.equal(ids[0], 0, "First option should have id 0");
    Assert.equal(ids[1], 1, "Second option should have id 1");
    Assert.equal(names[0], bytes32("option 1"), "First option name should be option 1");
    Assert.equal(names[1], bytes32("option 2"), "Second option name should be option 2");
    Assert.equal(urls[0], bytes32("option 1"), "First option url should be option 1");
    Assert.equal(urls[1], bytes32("option 2"), "Second option url should be option 2");
  }

  // Test create a campaign with 2 options and only vote option 0
  function testVoteOneOption() public {
    KyVote kyVote = KyVote(DeployedAddresses.KyVote());
    testCreateNewCampaign();
    uint numberCampaigns = kyVote.getTotalNumberCampaigns();
    // id of new campaign: numberCampaigns - 1;
    bytes32[] memory oldVoterIDs0 = kyVote.getVoterIDs(numberCampaigns - 1, 0);
    bytes32[] memory oldVoterIDs1 = kyVote.getVoterIDs(numberCampaigns - 1, 1);
    uint[] memory voteOptions = new uint[](1);
    voteOptions[0] = 0;
    kyVote.vote(bytes32("mikele"), numberCampaigns - 1, voteOptions);
    bytes32[] memory newVoterIDs0 = kyVote.getVoterIDs(numberCampaigns - 1, 0);
    bytes32[] memory newVoterIDs1 = kyVote.getVoterIDs(numberCampaigns - 1, 1);
    Assert.equal(oldVoterIDs0.length + 1, newVoterIDs0.length, "New voter should be added to option 0");
    Assert.equal(oldVoterIDs1.length, newVoterIDs1.length, "New voter should not be added to option 1");
    uint i;
    bool contains = false;
    for(i = 0; i < newVoterIDs0.length; i++) {
      if (newVoterIDs0[i] == bytes32("mikele")) { contains = true; break; }
    }
    Assert.equal(contains, true, "Voters of option 0 should contain mikele");
    contains = false;
    for(i = 0; i < newVoterIDs1.length; i++) {
      if (newVoterIDs1[i] == bytes32("mikele")) { contains = true; break; }
    }
    Assert.equal(contains, false, "Voters of option 1 should not contain mikele");
  }

  // Test create a multiple choice campaign with 2 options and vote all options
  function testVoteAllOptions() public {
    KyVote kyVote = KyVote(DeployedAddresses.KyVote());
    testCreateNewCampaign();
    uint numberCampaigns = kyVote.getTotalNumberCampaigns();
    // id of new campaign: numberCampaigns - 1;
    // Get option 0 of new campaign
    bytes32[] memory oldVoterIDs0 = kyVote.getVoterIDs(numberCampaigns - 1, 0);
    bytes32[] memory oldVoterIDs1 = kyVote.getVoterIDs(numberCampaigns - 1, 1);
    uint[] memory voteOptions = new uint[](2);
    voteOptions[0] = 0;
    voteOptions[1] = 1;
    kyVote.vote(bytes32("mikele"), numberCampaigns - 1, voteOptions);
    bytes32[] memory newVoterIDs0 = kyVote.getVoterIDs(numberCampaigns - 1, 0);
    bytes32[] memory newVoterIDs1 = kyVote.getVoterIDs(numberCampaigns - 1, 1);
    Assert.equal(oldVoterIDs0.length + 1, newVoterIDs0.length, "New voter should be added to option 0");
    Assert.equal(oldVoterIDs1.length + 1, newVoterIDs1.length, "New voter should be added to option 1");
    uint i;
    bool contains = false;
    for(i = 0; i < newVoterIDs0.length; i++) {
      if (newVoterIDs0[i] == bytes32("mikele")) { contains = true; break; }
    }
    Assert.equal(contains, true, "Voters of option 0 should contain mikele");
    contains = false;
    for(i = 0; i < newVoterIDs1.length; i++) {
      if (newVoterIDs1[i] == bytes32("mikele")) { contains = true; break; }
    }
    Assert.equal(contains, true, "Voters of option 1 should contain mikele");
  }

  // Test create a multiple choice campaign with 2 options and vote all options
  // Then unvote only option 0
  function testUnVoteAnOptionInMultipleChoice() public {
    KyVote kyVote = KyVote(DeployedAddresses.KyVote());
    testVoteAllOptions();
    uint numberCampaigns = kyVote.getTotalNumberCampaigns();
    // id of new campaign: numberCampaigns - 1;
    bytes32[] memory oldVoterIDs0 = kyVote.getVoterIDs(numberCampaigns - 1, 0);
    bytes32[] memory oldVoterIDs1 = kyVote.getVoterIDs(numberCampaigns - 1, 1);
    uint[] memory voteOptions = new uint[](1);
    voteOptions[0] = 1;
    // vote option contains only 1, mean unvote option 0
    kyVote.vote(bytes32("mikele"), numberCampaigns - 1, voteOptions);
    bytes32[] memory newVoterIDs0 = kyVote.getVoterIDs(numberCampaigns - 1, 0);
    bytes32[] memory newVoterIDs1 = kyVote.getVoterIDs(numberCampaigns - 1, 1);
    Assert.equal(oldVoterIDs0.length - 1, newVoterIDs0.length, "The voter should be removed from option 0");
    Assert.equal(oldVoterIDs1.length, newVoterIDs1.length, "The voter should be stayed in option 1");
    uint i;
    bool contains = false;
    for(i = 0; i < newVoterIDs0.length; i++) {
      if (newVoterIDs0[i] == bytes32("mikele")) { contains = true; break; }
    }
    Assert.equal(contains, false, "Voters of option 0 should not contain mikele");
    contains = false;
    for(i = 0; i < newVoterIDs1.length; i++) {
      if (newVoterIDs1[i] == bytes32("mikele")) { contains = true; break; }
    }
    Assert.equal(contains, true, "Voters of option 1 should contain mikele");
  }

  // Test stop an active campaign
  function testStopAnActiveCampaign() public {
    KyVote kyVote = KyVote(DeployedAddresses.KyVote());
    testCreateNewCampaign();
    uint numberCampaigns = kyVote.getTotalNumberCampaigns();
    // new campaignID is numberCampaigns - 1
    Assert.equal(kyVote.isCampaignEnded(numberCampaigns - 1), false, "Campaign should be still active");
    kyVote.stopCampaign(numberCampaigns - 1);
    Assert.equal(kyVote.isCampaignEnded(numberCampaigns - 1), true, "Campaign should be ended");
  }
}
