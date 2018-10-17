pragma solidity ^0.4.18;

import "./ERC20Interface.sol";

contract KyVote {

  constructor() public payable { owner = msg.sender; }
  address public owner;

  event WithdrawETH(uint amount);
  event WithdrawToken(ERC20 token, uint amount);

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner can call this function");
    _; // will be replaced by actual function body when modifier is called
  }

  // Withdraw ETH from contract to owner account
  function withdrawETH(uint amount) public onlyOwner returns (bool) {
    require(amount <= owner.balance, "Can not withdraw more than balance");
    owner.transfer(amount);
    emit WithdrawETH(amount);
    return true;
  }

  // Withdraw ERC token from contract to owner account
  function withdrawToken(ERC20 token, uint amount) public onlyOwner returns (bool) {
    require(token.transfer(msg.sender, amount));
    emit WithdrawToken(token, amount);
    return true;
  }

  // Get contract ETH balance
  function getContractETHBalance() public view returns (uint) {
    return address(this).balance;
  }

  // Get contract token balance
  function getContractTokenBalance(ERC20 token) public view returns (uint) {
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
    bytes32 name;
    bytes32 url;
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
    //uint id;
    bytes32 title;
    mapping (uint => Option) options;
    uint optionCount;
    uint end;
    address admin;
    bool isMultipleChoices;
    address[] whitelistedAddresses;
  }

  // Mapping from campaignID => campaign object, id of campaign is set from 0
  mapping (uint => Campaign) campaigns;
  // Number of created campaigns
  uint numberCampaigns;

  // Create new campaign with fully details of options, return campaign ID
  // title: Title of campaign
  // optionNames, optionURLs: list of names and urls for list of options
  // end: ending time for this campaign
  // isMultipleChoices: allow multiple choices vote or not
  // whitelistedAddresses: whitelisted addresses for this campaign, can be updated by admin
  // admin of the campaign is the sender
  function createCampaign(
    bytes32 title,
    bytes32[] memory optionNames,
    bytes32[] memory optionURLs,
    uint end,
    bool isMultipleChoices,
    address[] memory whitelistedAddresses
  ) public payable returns (uint) {
    require(optionNames.length == optionURLs.length, "Option names and urls should have same length");
    require(optionNames.length > 0, "Option names and urls should not be empty");
    require(end > now, "End time should greater than current block timestamp");
    // new campaign will have campaign ID equals the current number of campaigns
    // as new campaign is created, number of campaigns increases by 1
    uint campaignID = numberCampaigns++;
    // map the ID to the new campaign
    campaigns[campaignID] = Campaign({
      title: title,
      end: end,
      admin: msg.sender,
      isMultipleChoices: isMultipleChoices,
      optionCount: optionNames.length,
      whitelistedAddresses: whitelistedAddresses
    });
    address[] memory voters = new address[](0);
    // Adding list options to new campaign
    for(uint i0 = 0; i0 < optionNames.length; i0++) {
      // Option ID is started from 0, map option ID to new option
      campaigns[campaignID].options[i0] = Option({id: i0, name: optionNames[i0], url: optionURLs[i0], voters: voters});
    }
    emit AddCampaign(campaignID);
    return campaignID;
  }

  // Add more whitelisted addresses
  function addWhitelistedAddresses(uint campaignID, address[] memory addresses) public payable {
    require(campaignID < numberCampaigns, "Campaign does not exist");
    Campaign storage camp = campaigns[campaignID];
    require(camp.admin == msg.sender, "Only campaign admin can call this function");
    // An easy way to test
    address[] memory whitelisted = camp.whitelistedAddresses;
    for (uint ii0 = 0; ii0 < addresses.length; ii0++) {
      whitelisted = addNewElementToArrayIfNeeded(whitelisted, addresses[ii0]);
    }
    camp.whitelistedAddresses = whitelisted;
  }

  // Remove whitelisted addresses
  // Remove an address will also remove all of its voted options
  function removeWhitelistedAddresses(uint campaignID, address[] memory addresses) public payable {
    require(campaignID < numberCampaigns, "Campaign does not exist");
    Campaign storage camp = campaigns[campaignID];
    require(camp.admin == msg.sender, "Only campaign admin can call this function");
    // An easy way to test
    address[] memory whitelisted = camp.whitelistedAddresses;
    for (uint ii0 = 0; ii0 < addresses.length; ii0++) {
      whitelisted = removeAnElementFromArrayIfNeeded(whitelisted, addresses[ii0]);
      // Remove this address out of voters for each option in this campaign if needed
      for(uint j0 = 0; j0 < camp.optionCount; j0++) {
        Option storage op1 = camp.options[j0];
        op1.voters = removeAnElementFromArrayIfNeeded(op1.voters, addresses[ii0]);
      }
    }
    camp.whitelistedAddresses = whitelisted;
  }

  // Override list of whitelisted addresses
  function updateNewWhitelistedAddresses(uint campaignID, address[] memory addresses) public payable {
    require(campaignID < numberCampaigns, "Campaign does not exist");
    Campaign storage camp = campaigns[campaignID];
    require(camp.admin == msg.sender, "Only campaign admin can call this function");
    for (uint ii1 = 0; ii1 < camp.whitelistedAddresses.length; ii1++) {
      bool _contain = false;
      address addr = camp.whitelistedAddresses[ii1];
      for(uint ii2 = 0; ii2 < addresses.length; ii2++) {
        if (addresses[ii2] == addr) {
          _contain = true; break;
        }
      }
      if (!_contain) {
        // new whitelisted addresses does not contain the address camp.whitelistedAddresses[ii1]
        // Check each option in campaign, if this address has voted for the option, then unvote it
        for(uint jj0 = 0; jj0 < camp.optionCount; jj0++) {
          Option storage op1 = camp.options[jj0];
          op1.voters = removeAnElementFromArrayIfNeeded(op1.voters, addr);
        }
      }
    }
    campaigns[campaignID].whitelistedAddresses = addresses;
  }

  // Stop a campaign
  function stopCampaign(uint campaignID) public payable {
    require(campaignID < numberCampaigns, "Campaign does not exist");
    require(campaigns[campaignID].admin == msg.sender, "Only campaign admin can stop the campaign"); // only admin can stop the campaign
    campaigns[campaignID].end = now;
    emit StopCampaign(campaignID);
  }

  // vote for options given list options and campaign ID, voter: id of voter, e.g: telegram id
  function vote(uint campaignID, uint[] memory optionIDs) public payable {
    require(campaignID < numberCampaigns, "Campaign not found");
    Campaign storage camp = campaigns[campaignID];
    require(camp.end > now, "Campaign should be running");
    if (!camp.isMultipleChoices) {
      require(optionIDs.length <= 1, "Can not vote multi options for none multi choices campaign"); // not multiple choices, then can not vote for more than 1 option
    }
    uint i1;
    bool whitelisted = false;
    for (i1 = 0; i1 < camp.whitelistedAddresses.length; i1++) {
      if (camp.whitelistedAddresses[i1] == msg.sender) {
        whitelisted = true; break;
      }
    }
    require(whitelisted == true, "Only whitelisted account can vote");
    // Adding the voter ID to list of voters for each voted option
    for (i1 = 0; i1 < optionIDs.length; i1++) {
      require(optionIDs[i1] >= 0 && optionIDs[i1] < camp.optionCount, "Voted options should be in the list of options");
      Option storage op1 = camp.options[optionIDs[i1]];
      // add voter to voters list if needed
      op1.voters = addNewElementToArrayIfNeeded(op1.voters, msg.sender);
    }
    // use contains to check if an option is in the list new voted options
    bool[] memory contains = new bool[](camp.optionCount);
    uint optionCount = camp.optionCount;
    for(i1 = 0; i1 < optionCount; i1++) { contains[i1] = false; }
    for(i1 = 0; i1 < optionIDs.length; i1++) { contains[optionIDs[i1]] = true; }
    for (i1 = 0; i1 < optionCount; i1++) {
      if (!contains[i1]) {
        // option i1 is not in the list of optionIDs, so it means user unvoted i1 (if voted)
        // remove this voter from option i1 voters if needed
        camp.options[i1].voters = removeAnElementFromArrayIfNeeded(camp.options[i1].voters, msg.sender);
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

  // return campaignDetails without list of options, data returns include (id, title, end, admin, isMultipleChoices)
  function getCampaignDetails(uint campaignID) public view returns (uint, bytes32, uint, address, bool) {
    require(campaignID < numberCampaigns);
    return (
      campaignID,
      campaigns[campaignID].title,
      campaigns[campaignID].end,
      campaigns[campaignID].admin,
      campaigns[campaignID].isMultipleChoices
    );
  }

  // get whitelisted addresses, only allow admin of the campaign
  function getCampaignWhitelistedAddresses(uint campaignID) public view returns (address[]) {
    require(campaignID < numberCampaigns);
    require(campaigns[campaignID].admin == msg.sender);
    return campaigns[campaignID].whitelistedAddresses;
  }

  // check if an address is whitelisted, allow all access
  function checkWhitelisted(uint campaignID, address _account) public view returns (bool) {
    require(campaignID < numberCampaigns);
    for (uint ii = 0; ii < campaigns[campaignID].whitelistedAddresses.length; ii++) {
      if (campaigns[campaignID].whitelistedAddresses[ii] == _account) { return true; }
    }
    return false;
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

  // get fully details of an option given its ID and campaignID, (id, name, url, voters)
  function getOption(uint campaignID, uint optionID) public view returns (uint, bytes32, bytes32, address[]) {
    require(campaignID < numberCampaigns && optionID >= 0);
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
    require(campaignID < numberCampaigns && optionID >= 0);
    require(optionID < campaigns[campaignID].optionCount);
    return campaigns[campaignID].options[optionID].voters;
  }

  // optional function to update end time (earlier or later)
  // function updateEndTime(uint campaignID, uint end) public {
  //   require(campaignID < numberCampaigns);
  //   require(end > now); // new end time should be greater than current time block
  //   require(campaigns[campaignID].admin == msg.sender); // only admin can update info of a campaign
  //   campaigns[campaignID].end = end;
  //   emit UpdateCampaign(campaignID);
  // }

  // return total number of all campaigns
  function getTotalNumberCampaigns() public view returns (uint) {
    return numberCampaigns;
  }

  // Remove an element from an array if needed
  function removeAnElementFromArrayIfNeeded(address[] memory array, address element) internal pure returns (address[]) {
    uint index = array.length;
    uint i5;
    // check if need to remove the element from array
    for(i5 = 0; i5 < array.length; i5++) {
      if (array[i5] == element) {
        index = i5; break;
      }
    }
    if (index == array.length) { return array; } // voters does not contain id
    // element is in the array, need to remove it
    address[] memory newArray = new address[](array.length - 1);
    uint count = 0;
    for (i5 = 0; i5 < array.length; i5++) {
      if (i5 == index) { continue; }
      newArray[count++] = array[i5];
    }
    return newArray;
  }

  // Add new element to an array if it is not in the array yet
  function addNewElementToArrayIfNeeded(address[] memory array, address element) internal pure returns (address[]) {
    uint i6;
    for(i6 = 0; i6 < array.length; i6++) {
      if (array[i6] == element) {
        return array; // already existed, no need to add
      }
    }
    // element is not in the array, append to end of list
    address[] memory newArray = new address[](array.length + 1);
    for (i6 = 0; i6 < array.length; i6++) {
      newArray[i6] = array[i6];
    }
    newArray[array.length] = element;
    return newArray;
  }
}
