pragma solidity ^0.4.18;

interface Token {
    function balanceOf(address _owner) external view returns (uint balance);
    function transfer(address _to, uint _value) external returns (bool success);
}

contract KyVote {

  constructor() public { owner = msg.sender; }
  address public owner;

  event WithdrawETH(uint amount);
  event WithdrawToken(Token token, uint amount);

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner can call this function");
    _; // will be replaced by actual function body when modifier is called
  }

  // Withdraw ETH from contract to owner account
  function withdrawETH(uint amount) public onlyOwner returns (bool) {
    require(amount <= address(this).balance, "Can not withdraw more than balance");
    owner.transfer(amount);
    emit WithdrawETH(amount);
    return true;
  }

  // Withdraw ERC token from contract to owner account
  function withdrawToken(Token token, uint amount) public onlyOwner returns (bool) {
    require(amount <= token.balanceOf(address(this)));
    bool result = token.transfer(msg.sender, amount);
    emit WithdrawToken(token, amount);
    return result;
  }

  // Get contract ETH balance
  function getContractETHBalance() public view returns (uint) {
    return address(this).balance;
  }

  // Get contract token balance
  function getContractTokenBalance(Token token) public view returns (uint) {
    return token.balanceOf(address(this));
  }

  event AddCampaign(uint campaignID);
  event StopCampaign(uint campaignID);
  event UpdateCampaign(uint campaignID);
  event Voted(address voter, uint campaignID, uint[] optionIDs);

  // Explain data:
  //  id: id of the option, it is unique for each campaign
  //  name: Option name
  //  url: Option url (if has link)
  //  voters: list of voter IDs that have voted for this option
  struct Option {
    uint id;
    bytes32[] name;
    bytes32[] url;
    address[] voters;
  }

  // Explain data:
  //  title: Title of the campaign, should be more specific about the purpose of campaign here but should fit bytes32 data
  //  options: Mappings list of options
  //  optionCount: Number of options
  //  end: ending time for campaign
  //  admin: address admin, only can stop (or might edit) the campaign using this admin address
  //  isMultipleChoices: is allowing multiple choices
  //  whitelistedAddresses: only these addresses can vote in this campaign
  struct Campaign {
    bytes32[] title;
    mapping (uint => Option) options;
    uint optionCount;
    uint end;
    address admin;
    bool isMultipleChoices;
    mapping (address => bool) whitelistedAddresses;
  }

  // Mapping from campaignID => campaign object, id of campaign is set from 0
  mapping (uint => Campaign) campaigns;
  // Number of created campaigns
  uint numberCampaigns;

  // Create new campaign with fully details of options, return campaign ID
  // title: Title of campaign using array of bytes32
  // optionNames, optionURLs: list of names and urls for list of options
  // end: ending time for this campaign
  // isMultipleChoices: allow multiple choices vote or not
  // whitelistedAddresses: whitelisted addresses for this campaign, can be updated by admin
  // admin of the campaign is the sender
  function createCampaign(
    bytes32[] memory title,
    bytes32[] memory optionNames,
    bytes32[] memory optionURLs,
    uint end,
    bool isMultipleChoices,
    address[] memory whitelistedAddresses
  ) public returns (uint) {
    require(end > now, "End time should greater than current block timestamp");
    // new campaign will have campaign ID equals the current number of campaigns
    // as new campaign is created, number of campaigns increases by 1
    // each option name is a list of bytes32 (as it is a string)
    // list of option names is an array of bytes32 separated by a \n
    uint i;
    uint j;

    // count number of option names, each end with "\n"
    uint optionNameCount = 0;
    for(i = 0; i < optionNames.length; i++) {
        if (optionNames[i] == bytes32("\n")) { optionNameCount++; }
    }
    require(optionNameCount > 0, "Should have options");

    // count number of option urls, each end with "\n"
    j = 0;
    for(i = 0; i < optionURLs.length; i++) {
        if (optionURLs[i] == bytes32("\n")) { j++; }
    }
    require(optionNameCount == j, "Number of names and urls should be the same");

    // Create new campaign
    uint campaignID = numberCampaigns++;
    // map the ID to the new campaign, data can not changed (except end time and whitelisted addresses)
    campaigns[campaignID] = Campaign({
      title: title,
      end: end,
      admin: msg.sender,
      isMultipleChoices: isMultipleChoices,
      optionCount: optionNameCount
    });

    // Adding list options to new campaign, can not changed
    i = 0; j = 0;
    for(uint id = 0; id < optionNameCount; id++) {
      // Count length of the option name id, omit "\n"
      uint nameLen = 0;
      while (nameLen + i < optionNames.length && optionNames[nameLen + i] != bytes32("\n")) { nameLen++; }
      // Count length of the option url id, omit "\n"
      uint urlLen = 0;
      while (urlLen + j < optionNames.length && optionURLs[urlLen + j] != bytes32("\n")) { urlLen++; }
      campaigns[campaignID].options[id] = Option({
        id: id,
        name: subArray(optionNames, i, nameLen),
        url: subArray(optionURLs, j, urlLen),
        voters: new address[](0)
      });
      // point to next option name and url
      i += nameLen + 1;
      j += urlLen + 1;
    }
    // Adding whitelisted addresses to the campaign, can be modified later
    for(i = 0; i < whitelistedAddresses.length; i++) {
        campaigns[campaignID].whitelistedAddresses[whitelistedAddresses[i]] = true;
    }
    emit AddCampaign(campaignID);
    return campaignID;
  }

  // Update whitelisted addresses, add or remove whitelistedAddresses
  // Remove an address will also remove all of its voted options
  function updateWhitelistedAddresses(uint campaignID, address[] memory addresses, bool isAdding) public {
    require(campaignID < numberCampaigns, "Campaign does not exist");
    Campaign storage camp = campaigns[campaignID];
    require(camp.admin == msg.sender, "Only campaign admin can call this function");
    for (uint i = 0; i < addresses.length; i++) {
        camp.whitelistedAddresses[addresses[i]] = isAdding;
        if (!isAdding) {
            for(uint j = 0; j < camp.optionCount; j++) {
                Option storage op = camp.options[j];
                uint index = getIndexOfElementInArray(op.voters, addresses[i]);
                if (index < op.voters.length) {
                    // Delete element at index 'index'
                    address temp = op.voters[index];
                    op.voters[index] = op.voters[op.voters.length - 1];
                    op.voters[op.voters.length - 1] = temp;
                    delete op.voters[op.voters.length - 1];
                    op.voters.length--;
                }
            }
        }
    }
  }

  // Stop a campaign
  function stopCampaign(uint campaignID) public {
    require(campaignID < numberCampaigns, "Campaign does not exist");
    require(campaigns[campaignID].admin == msg.sender, "Only campaign admin can stop the campaign"); // only admin can stop the campaign
    campaigns[campaignID].end = now;
    emit StopCampaign(campaignID);
  }

  // vote for options given list options and campaign ID, voter: id of voter, e.g: telegram id
  function vote(uint campaignID, uint[] memory optionIDs) public {
    require(campaignID < numberCampaigns, "Campaign not found");
    Campaign storage camp = campaigns[campaignID];
    require(camp.end > now, "Campaign should be running");
    require(camp.whitelistedAddresses[msg.sender] == true, "Only whitelisted account can vote");
    if (optionIDs.length > 1) {
      require(camp.isMultipleChoices, "Can not vote multi options for none multi choices campaign"); // not multiple choices, then can not vote for more than 1 option
    }
    uint i;
    // use contains to check if an option is in the list new voted options
    bool[] memory contains = new bool[](camp.optionCount);
    uint optionCount = camp.optionCount;
    for(i = 0; i < optionCount; i++) { contains[i] = false; }
    for(i = 0; i < optionIDs.length; i++) { contains[optionIDs[i]] = true; }
    for(i = 0; i < optionCount; i++) {
      if (!contains[i]) {
        // option i1 is not in the list of optionIDs, so it means user unvoted i1 (if voted)
        // remove this voter from option i1 voters if needed
        Option storage op = camp.options[i];
        uint index = getIndexOfElementInArray(op.voters, msg.sender);
        if (index < camp.options[i].voters.length) {
            // // Delete element at index
            address temp = op.voters[index];
            op.voters[index] = op.voters[op.voters.length - 1];
            op.voters[op.voters.length - 1] = temp;
            delete op.voters[op.voters.length - 1];
            op.voters.length--;
        }
      } else {
        if (getIndexOfElementInArray(camp.options[i].voters, msg.sender) == camp.options[i].voters.length) {
            // msg.sender is not in the voters of option i, push into voters list
            camp.options[i].voters.push(msg.sender);
        }
      }
    }
    emit Voted(msg.sender, campaignID, optionIDs);
  }

  // Return bool value indicate whether the campaign has ended (end time <= current block timestamp)
  function isCampaignEnded(uint campaignID) public view returns (bool) {
    require(campaignID < numberCampaigns);
    return campaigns[campaignID].end <= now;
  }

  // Return list of active campaign IDs
  function getListActiveCampaignIDs() public view returns (uint[]) {
    // Count number of active campaigns
    uint count = 0;
    uint i;
    for (i = 0; i < numberCampaigns; i++) {
      if (campaigns[i].end > now) { count++; }
    }

    // Add list of active campaigns to results list
    uint[] memory results = new uint[](count);
    count = 0;
    for (i = 0; i < numberCampaigns; i++) {
      if (campaigns[i].end > now) {
        results[count++] = i;
      }
    }
    return results;
  }

  // return campaignDetails without list of options, data returns include (id, title, end, admin, isMultipleChoices)
  function getCampaignDetails(uint campaignID) public view returns (uint, bytes32[], uint, address, bool) {
    require(campaignID < numberCampaigns);
    return (
      campaignID,
      campaigns[campaignID].title,
      campaigns[campaignID].end,
      campaigns[campaignID].admin,
      campaigns[campaignID].isMultipleChoices
    );
  }

  // check if an address is whitelisted, allow all access
  function checkWhitelisted(uint campaignID, address _account) public view returns (bool) {
    require(campaignID < numberCampaigns);
    return campaigns[campaignID].whitelistedAddresses[_account] == true;
  }

  // get options count for a given campaignID
  function getOptionsCount(uint campaignID) public view returns (uint) {
    require(campaignID < numberCampaigns);
    return campaigns[campaignID].optionCount;
  }

  // func get list of options for a given campaignID (ids, names, urls)
  // return 3 arrays with list data of option IDs, option names, option URLs
  function getListOptions(uint campaignID) public view returns (uint[], bytes32[], bytes32[]) {
    require(campaignID < numberCampaigns);
    uint[] memory ids = new uint[](campaigns[campaignID].optionCount);
    for(uint i = 0; i < campaigns[campaignID].optionCount; i++) {
      ids[i] = i;
    }
    bytes32[] memory names = optionNamesFromCampaign(campaignID);
    bytes32[] memory urls = optionURLsFromCampaign(campaignID);
    return (ids, names, urls);
  }

  // get fully details of an option given its ID and campaignID, (id, name, url, voters)
  function getOption(uint campaignID, uint optionID) public view returns (uint, bytes32[], bytes32[], address[]) {
    require(campaignID < numberCampaigns);
    require(optionID < campaigns[campaignID].optionCount);
    return (
      optionID,
      campaigns[campaignID].options[optionID].name,
      campaigns[campaignID].options[optionID].url,
      campaigns[campaignID].options[optionID].voters
    );
  }

  // option function return list of voters for given campaignID and optionID
  // mostly option data is not changed, but list voters is changing over time
  // getting fully details is redundant, (voters)
  function getVoters(uint campaignID, uint optionID) public view returns (address[]) {
    require(campaignID < numberCampaigns);
    require(optionID < campaigns[campaignID].optionCount);
    return campaigns[campaignID].options[optionID].voters;
  }

//   // optional function to update end time (earlier or later)
//   function updateEndTime(uint campaignID, uint end) public {
//      require(campaignID < numberCampaigns);
//      require(end > now); // new end time should be greater than current time block
//      require(campaigns[campaignID].admin == msg.sender); // only admin can update info of a campaign
//      campaigns[campaignID].end = end;
//      emit UpdateCampaign(campaignID);
//   }

  // return total number of all campaigns
  function getTotalNumberCampaigns() public view returns (uint) {
    return numberCampaigns;
  }

  // Getting index of an element in the array, return length of array if element is not in the array
  function getIndexOfElementInArray(address[] memory array, address element) internal pure returns (uint) {
    for(uint i = 0; i < array.length; i++) {
      if (array[i] == element) { return i; }
    }
    return array.length;
  }

  function subArray(bytes32[] memory array, uint start, uint len) internal pure returns (bytes32[]) {
    bytes32[] memory result = new bytes32[](len);
    for(uint i = 0 ; i < len; i++) {
      result[i] = array[i + start];
    }
    return result;
  }

  function optionNamesFromCampaign(uint campaignID) internal view returns (bytes32[]) {
    uint optionNameCount = campaigns[campaignID].optionCount;
    uint i;
    uint j;
    for(i = 0; i < campaigns[campaignID].optionCount; i++) {
        optionNameCount += campaigns[campaignID].options[i].name.length;
    }
    bytes32[] memory names = new bytes32[](optionNameCount);
    uint nameCount = 0;
    for (i = 0; i < campaigns[campaignID].optionCount; i++) {
        Option storage op = campaigns[campaignID].options[i];
        for(j = 0; j < op.name.length; j++) {
            names[nameCount++] = op.name[j];
        }
        names[nameCount++] = bytes32("\n");
    }
    return names;
  }

  function optionURLsFromCampaign(uint campaignID) internal view returns (bytes32[]) {
    uint optionURLCount = campaigns[campaignID].optionCount;
    uint i;
    uint j;
    for(i = 0; i < campaigns[campaignID].optionCount; i++) {
        optionURLCount += campaigns[campaignID].options[i].url.length;
    }
    bytes32[] memory urls = new bytes32[](optionURLCount);
    uint urlCount = 0;
    for (i = 0; i < campaigns[campaignID].optionCount; i++) {
        Option storage op = campaigns[campaignID].options[i];
        for(j = 0; j < op.url.length; j++) {
            urls[urlCount++] = op.url[j];
        }
        urls[urlCount++] = bytes32("\n");
    }
    return urls;
  }
}
