pragma solidity ^0.4.18;

contract KyVote {

  event AddCampaign(uint campaignID);
  event StopCampaign(uint campaignID);
  event UpdateCampaign(uint campaignID);
  event Voted(bytes32 voterID, uint campaignID, uint[] optionIDs);

  // Explain data:
  //  id: id of the option, it is unique for each campaign
  //  name: Option name
  //  url: Option url (if has link)
  //  voterIDs: list of voter IDs that have voted for this option
  struct Option {
    uint id;
    bytes32 name;
    bytes32 url;
    bytes32[] voterIDs;
  }

  // Explain data:
  //  title: Title of the campaign, should be more specific about the purpose of campaign here but should fit bytes32 data
  //  options: Mappings list of options
  //  optionCount: Number of options
  //  end: ending time for campaign
  //  creatorID: id of creator of the campaign, e.g telegram id
  //  admin: address admin, only can stop (or might edit) the campaign using this admin address
  //  isMultipleChoices: is allowing multiple choices
  struct Campaign {
    //uint id;
    bytes32 title;
    mapping (uint => Option) options;
    uint optionCount;
    uint end;
    bytes32 creatorID;
    address admin;
    bool isMultipleChoices;
  }

  // Mapping from campaignID => campaign object, id of campaign is set from 0
  mapping (uint => Campaign) campaigns;
  // Number of created campaigns
  uint numberCampaigns;

  // Create new campaign with fully details of options, return campaign ID
  // title: Title of campaign
  // optionNames, optionURLs: list of names and urls for list of options
  // end: ending time for this campaign
  // creatorID: ID of the creator of the new campaign, e.g: telegram ID
  // isMultipleChoices: allow multiple choices vote or not
  // admin of the campaign is the sender
  function createCampaign(
    bytes32 title,
    bytes32[] optionNames,
    bytes32[] optionURLs,
    uint end,
    bytes32 creatorID,
    bool isMultipleChoices
  ) public returns (uint) {
    require(optionNames.length == optionURLs.length, "Option names and urls should have same length");
    require(optionNames.length > 0, "Option names and urls should not be empty");
    require(end > now, "End time should greater than current block timestamp");
    // new campaign will have campaign ID equals the current number of campaigns
    // as new campaign is created, number of campaigns increases by 1
    uint campaignID = numberCampaigns++;
    // map the ID to the new campaign
    campaigns[campaignID] = Campaign({title: title, end: end, admin: msg.sender, creatorID: creatorID, isMultipleChoices: isMultipleChoices, optionCount: optionNames.length});
    bytes32[] memory voterIDs = new bytes32[](0);
    // Adding list options to new campaign
    for(uint i0 = 0; i0 < optionNames.length; i0++) {
      // Option ID is started from 0, map option ID to new option
      campaigns[campaignID].options[i0] = Option({id: i0, name: optionNames[i0], url: optionURLs[i0], voterIDs: voterIDs});
    }
    emit AddCampaign(campaignID);
    return campaignID;
  }

  // Stop a campaign
  function stopCampaign(uint campaignID) public {
    require(campaigns[campaignID].admin == msg.sender, "Only campaign admin can stop the campaign"); // only admin can stop the campaign
    require(campaignID < numberCampaigns && campaignID >= 0, "Campaign does not exist");
    campaigns[campaignID].end = now;
    emit StopCampaign(campaignID);
  }

  // vote for options given list options and campaign ID, voterID: id of voter, e.g: telegram id
  function vote(bytes32 voterID, uint campaignID, uint[] optionIDs) public {
    require(campaignID < numberCampaigns && campaignID >= 0, "Campaign not found");
    Campaign storage camp = campaigns[campaignID];
    require(camp.end > now, "Campaign should be running");
    if (!camp.isMultipleChoices) {
      require(optionIDs.length <= 1, "Can not vote multi options for none multi choices campaign"); // not multiple choices, then can not vote for more than 1 option
    }
    uint i1;
    // Adding the voter ID to list of voterIDs for each voted option
    for (i1 = 0; i1 < optionIDs.length; i1++) {
      require(optionIDs[i1] >= 0 && optionIDs[i1] < camp.optionCount, "Voted options should be in the list of options");
      Option storage op1 = camp.options[optionIDs[i1]];
      // add voterID to voterIDs list if needed
      op1.voterIDs = addVoterIfNeeded(op1.voterIDs, voterID);
    }
    // use contains to check if an option is in the list new voted options
    bool[] memory contains = new bool[](camp.optionCount);
    uint optionCount = camp.optionCount;
    for(i1 = 0; i1 < optionCount; i1++) { contains[i1] = false; }
    for(i1 = 0; i1 < optionIDs.length; i1++) { contains[optionIDs[i1]] = true; }
    for (i1 = 0; i1 < optionCount; i1++) {
      if (!contains[i1]) {
        // option i1 is not in the list of optionIDs, so it means user unvoted i1 (if voted)
        // remove this voter from option i1 voterIDs if needed
        camp.options[i1].voterIDs = removeVoterIfNeed(camp.options[i1].voterIDs, voterID);
      }
    }
    emit Voted(voterID, campaignID, optionIDs);
  }

  // Return bool value indicate whether the campaign has ended (end time <= current block timestamp)
  function isCampaignEnded(uint campaignID) public view returns (bool) {
    require(campaignID < numberCampaigns && campaignID >= 0);
    return campaigns[campaignID].end <= now;
  }

  // Return list of active campaign IDs
  function getListActiveCampaignIDs() public view returns (uint[]) {
    uint i3;

    // Count number of active campaigns
    uint count = 0;
    for (i3 = 0; i3 < numberCampaigns; i3++) {
      if (campaigns[i3].end > now) { count++; }
    }

    // Add list of active campaigns to results list
    uint[] memory results = new uint[](count);
    for (i3 = 0; i3 < numberCampaigns; i3++) {
      if (campaigns[i3].end > now) {
        results[--count] = i3;
      }
    }
    return results;
  }

  // return campaignDetails without list of options, data returns include (id, title, end, creatorID, admin, isMultipleChoices)
  function getCampaignDetails(uint campaignID) public view returns (uint, bytes32, uint, bytes32, address, bool) {
    require(campaignID >= 0 && campaignID < numberCampaigns);
    return (
      campaignID,
      campaigns[campaignID].title,
      campaigns[campaignID].end,
      campaigns[campaignID].creatorID,
      campaigns[campaignID].admin,
      campaigns[campaignID].isMultipleChoices
    );
  }

  // get options count for a given campaignID
  function getOptionsCount(uint campaignID) public view returns (uint) {
    require(campaignID >= 0 && campaignID < numberCampaigns);
    return campaigns[campaignID].optionCount;
  }

  // func get list of options for a given campaignID (ids, names, urls)
  // return 3 arrays with list data of option IDs, option names, option URLs
  function getListOptions(uint campaignID) public view returns (uint[], bytes32[], bytes32[]) {
    require(campaignID >= 0 && campaignID < numberCampaigns);
    uint count = campaigns[campaignID].optionCount;
    uint[] memory ids = new uint[](count);
    bytes32[] memory names = new bytes32[](count);
    bytes32[] memory urls = new bytes32[](count);
    for (uint i4 = 0; i4 < count; i4++) {
      Option storage op4 = campaigns[campaignID].options[i4];
      ids[i4] = op4.id;
      names[i4] = op4.name;
      urls[i4] = op4.url;
    }
    return (ids, names, urls);
  }

  // get fully details of an option given its ID and campaignID, (id, name, url, voterIDs)
  function getOption(uint campaignID, uint optionID) public view returns (uint, bytes32, bytes32, bytes32[]) {
    require(campaignID >= 0 && campaignID < numberCampaigns && optionID >= 0);
    require(optionID < campaigns[campaignID].optionCount);
    return (
      optionID,
      campaigns[campaignID].options[optionID].name,
      campaigns[campaignID].options[optionID].url,
      campaigns[campaignID].options[optionID].voterIDs
    );
  }

  // option function return list of voters for given campaignID and optionID
  // mostly option data is not changed, but list voters is changing over time
  // getting fully details is redundant, (voterIDs)
  function getVoterIDs(uint campaignID, uint optionID) public view returns (bytes32[]) {
    require(campaignID >= 0 && campaignID < numberCampaigns && optionID >= 0);
    require(optionID < campaigns[campaignID].optionCount);
    return campaigns[campaignID].options[optionID].voterIDs;
  }

  // optional function to update end time (earlier or later)
  // function updateEndTime(uint campaignID, uint end) public {
  //   require(campaignID >= 0 && campaignID < numberCampaigns);
  //   require(end > now); // new end time should be greater than current time block
  //   require(campaigns[campaignID].admin == msg.sender); // only admin can update info of a campaign
  //   campaigns[campaignID].end = end;
  //   emit UpdateCampaign(campaignID);
  // }

  // return total number of all campaigns
  function getTotalNumberCampaigns() public view returns (uint) {
    return numberCampaigns;
  }

  // Remove a voter from array if needed
  function removeVoterIfNeed(bytes32[] voters, bytes32 id) internal pure returns (bytes32[]) {
    uint index = voters.length;
    uint i5;
    // check if need to remove id out of voters
    for(i5 = 0; i5 < voters.length; i5++) {
      if (voters[i5] == id) {
        index = i5; break;
      }
    }
    if (index == voters.length) { return voters; } // voters does not contain id
    // id is in the list voters, need to remove it
    bytes32[] memory voterIDs = new bytes32[](voters.length - 1);
    uint count = 0;
    for (i5 = 0; i5 < voters.length; i5++) {
      if (i5 == index) { continue; }
      voterIDs[count++] = voters[i5];
    }
    return voterIDs;
  }

  // Add new voter with id to voters if it is not in the list
  function addVoterIfNeeded(bytes32[] voters, bytes32 id) internal pure returns (bytes32[]) {
    uint i6;
    for(i6 = 0; i6 < voters.length; i6++) {
      if (voters[i6] == id) {
        return voters; // already existed, no need to add
      }
    }
    // id is not in the voters, append to end of list
    bytes32[] memory voterIDs = new bytes32[](voters.length + 1);
    for (i6 = 0; i6 < voters.length; i6++) {
      voterIDs[i6] = voters[i6];
    }
    voterIDs[voters.length] = id;
    return voterIDs;
  }
}
