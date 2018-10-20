pragma solidity ^0.4.18;

interface ERC20 {
    function totalSupply() external view returns (uint supply);
    function balanceOf(address _owner) external view returns (uint balance);
    function transfer(address _to, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint _value) external returns (bool success);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint remaining);
    function decimals() external view returns(uint digits);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

contract KyVote {

  uint private constant OPTION_ID_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
  uint private constant CAMP_ID_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;
  uint private constant CAMP_OPTION_COUNT_MASK = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;
  uint private constant CAMP_END_TIME_MASK = 0x00000000000000000000000000000000fffffffffffffffffffffffffffffff0;
  uint private constant CAMP_IS_MULTI_CHOICES_MASK = 0x000000000000000000000000000000000000000000000000000000000000000f;

  constructor() public { owner = msg.sender; }
  address public owner;

  event WithdrawETH(uint amount);
  event WithdrawToken(ERC20 token, uint amount);

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner can call this function");
    _; // will be replaced by actual function body when modifier is called
  }

  // Withdraw ETH from contract to owner account
  function withdrawETH(uint amount) public onlyOwner {
    require(amount <= address(this).balance, "Can not withdraw more than balance");
    owner.transfer(amount);
    emit WithdrawETH(amount);
  }

  // Withdraw ERC token from contract to owner account
  function withdrawToken(ERC20 token, uint amount) public onlyOwner {
    require(amount <= token.balanceOf(address(this)));
    token.transfer(msg.sender, amount);
    emit WithdrawToken(token, amount);
  }

  // Get contract ETH balance
  function getContractETHBalance() public view returns (uint balance) {
    return address(this).balance;
  }

  // Get contract token balance
  function getContractTokenBalance(ERC20 token) public view returns (uint balance) {
    return token.balanceOf(address(this));
  }

  event AddCampaign(uint campaignID);
  event StopCampaign(uint campaignID);
  event UpdateCampaign(uint campaignID);
  event Voted(address voter, uint campaignID, uint[] optionIDs);

  // Explain data:
  //  name: Option name
  //  url: Option url (if has link)
  //  voters: list of voter IDs that have voted for this option
  struct Option {
    bytes32 name;
    bytes32 url;
    address[] voters;
  }

  // Explain data:
  //  title: Title of the campaign, should be more specific about the purpose of campaign here but should fit bytes32 data
  //  info: Merged of 3 data: optionCount, ending time and isMultipleChoices
  //  admin: address admin, only can stop (or might edit) the campaign using this admin address
  //  whitelistedAddresses: only these addresses can vote in this campaign
  struct Campaign {
    bytes32 title;
    uint info;
    address admin;
    mapping (address => bool) whitelistedAddresses;
  }

  // Mapping from merged ID (campaginID + optionID) to an Option
  mapping (uint => Option) options;
  // Mapping from campaignID => campaign object, id of campaign is set from 0
  mapping (uint => Campaign) campaigns;
  // Number of created campaigns
  uint numberCampaigns;

  // Create new campaign with fully details of options, return campaign ID
  // title: Title of campaign
  // optionNames, optionURLs: list of names and urls for list of options
  // moreInfo: contains ending time and isMultipleChoices
  // whitelistedAddresses: whitelisted addresses for this campaign, can be updated by admin
  // admin of the campaign is the sender
  function createCampaign(
    bytes32 title,
    bytes32[] memory optionNames,
    bytes32[] memory optionURLs,
    uint moreInfo,
    address[] memory whitelistedAddresses
  ) public returns (uint) {
    require(optionNames.length == optionURLs.length, "Option names and urls should have same length");
    require(optionNames.length > 0 && ((moreInfo & CAMP_END_TIME_MASK) >> 4) > now);
    // new campaign will have campaign ID equals the current number of campaigns
    // as new campaign is created, number of campaigns increases by 1
    uint campaignID = numberCampaigns++;
    // map the ID to the new campaign
    uint campInfo = (optionNames.length << 128) | moreInfo;
    campaigns[campaignID] = Campaign({
      title: title,
      info: campInfo,
      admin: msg.sender
    });
    uint idMask = campaignID << 128;
    // Adding list options to new campaign
    for(uint i = 0; i < optionNames.length; i++) {
        // Option ID is started from 0 for each campaign, merge with campaign ID, map option ID to new option
        options[idMask | i] = Option({name: optionNames[i], url: optionURLs[i], voters: new address[](0)});
    }
    if (whitelistedAddresses.length > 0) {
        for(i = 0; i < whitelistedAddresses.length; i++) {
            campaigns[campaignID].whitelistedAddresses[whitelistedAddresses[i]] = true;
        }
    }
    emit AddCampaign(campaignID);
    return campaignID;
  }

  // Update whitelisted addresses, add or remove whitelistedAddresses
  // Remove an address will also remove all of its voted options
  // data: merged of campaginID (uint) and isAdding (bool)
  function updateWhitelistedAddresses(uint data, address[] memory addresses) public {
    uint campaignID = (data >> 4);
    bool isAdding = (data & CAMP_IS_MULTI_CHOICES_MASK) == 1;
    Campaign storage camp = campaigns[campaignID];
    require(camp.admin == msg.sender, "Only campaign admin can call this function");
    uint campIDMask = campaignID << 128;
    for (uint i = 0; i < addresses.length; i++) {
        camp.whitelistedAddresses[addresses[i]] = isAdding;
        if (!isAdding) {
            uint optionCount = (camp.info & CAMP_OPTION_COUNT_MASK) >> 128;
            for(uint j = 0; j < optionCount; j++) {
                address[] storage voters = options[j | campIDMask].voters;
                uint index = getIndexOfElementInArray(voters, addresses[i]);
                if (index < voters.length) {
                    // Delete element at index, swap with last element if needed, then delete the last element
                    // here we don't care about the order of voters
                    if (index != voters.length - 1) {
                        address temp = voters[index];
                        voters[index] = voters[voters.length - 1];
                        voters[voters.length - 1] = temp;
                    }
                    delete voters[voters.length - 1];
                    voters.length--;
                }
            }
        }
    }
  }

  // Stop a campaign
  function stopCampaign(uint campaignID) public {
    require(campaigns[campaignID].admin == msg.sender, "Only campaign admin can stop the campaign"); // only admin can stop the campaign
    uint campInfo = campaigns[campaignID].info;
    campaigns[campaignID].info = (campInfo & CAMP_OPTION_COUNT_MASK) | (now << 4) | (campInfo & CAMP_IS_MULTI_CHOICES_MASK);
    emit StopCampaign(campaignID);
  }

  // vote for options given list options and campaign ID, voter: id of voter, e.g: telegram id
  // hard to use mergeID here as optionIDs could be empty array
  function vote(uint campaignID, uint[] memory optionIDs) public {
    require(campaignID < numberCampaigns, "Campaign not found");
    Campaign storage camp = campaigns[campaignID];
    require(camp.whitelistedAddresses[msg.sender] == true, "Only whitelisted account can vote");
    uint campInfo = camp.info;
    require(((campInfo & CAMP_END_TIME_MASK) >> 4) > now, "Campaign should be running");
    if (optionIDs.length > 1) {
      require((campInfo & CAMP_IS_MULTI_CHOICES_MASK) == 1, "Can not vote multi options for none multi choices campaign"); // not multiple choices, then can not vote for more than 1 option
    }
    uint campIDMask = campaignID << 128;
    uint i;
    // use contains to check if an option is in the list new voted options
    uint optionCount = (campInfo & CAMP_OPTION_COUNT_MASK) >> 128;
    bool[] memory contains = new bool[](optionCount);
    for(i = 0; i < optionCount; i++) { contains[i] = false; }
    for(i = 0; i < optionIDs.length; i++) {
        require(optionIDs[i] < optionCount);
        contains[optionIDs[i]] = true;
    }
    for(i = 0; i < optionCount; i++) {
      address[] storage voters = options[i | campIDMask].voters;
      if (!contains[i]) {
        // option i is not in the list of optionIDs, so it means user unvoted it (if have voted)
        // remove this voter from option i voters if needed
        uint index = getIndexOfElementInArray(voters, msg.sender);
        if (index < voters.length) {
            // Delete element at index, swap with last element if needed, then delete the last element
            if (index < voters.length - 1) {
                address temp = voters[index];
                voters[index] = voters[voters.length - 1];
                voters[voters.length - 1] = temp;
            }
            delete voters[voters.length - 1];
            voters.length--;
        }
      } else {
        // user voted for this option
        if (getIndexOfElementInArray(voters, msg.sender) == voters.length) {
            // msg.sender is not in the voters of option i, push into voters list
            voters.push(msg.sender);
        }
      }
    }
    emit Voted(msg.sender, campaignID, optionIDs);
  }

  // Return bool value indicate whether the campaign has ended (end time <= current block timestamp)
  function isCampaignEnded(uint campaignID) public view returns (bool isEnded) {
    require(campaignID < numberCampaigns);
    return ((campaigns[campaignID].info & CAMP_END_TIME_MASK) >> 4) <= now;
  }

  // Return list of active campaign IDs
  function getListActiveCampaignIDs() public view returns (uint[] memory campaignIDs) {
    // Count number of active campaigns
    uint count = 0;
    uint i;
    for (i = 0; i < numberCampaigns; i++) {
      if (((campaigns[i].info & CAMP_END_TIME_MASK) >> 4) > now) { count++; }
    }

    // Add list of active campaigns to results list
    campaignIDs = new uint[](count);
    count = 0;
    for (i = 0; i < numberCampaigns; i++) {
      if (((campaigns[i].info & CAMP_END_TIME_MASK) >> 4) > now) {
        campaignIDs[count++] = i;
      }
    }
    return campaignIDs;
  }

  // return campaignDetails without list of options, data returns include (title, end, admin, isMultipleChoices)
  function getCampaignDetails(uint campaignID) public view returns (bytes32 title, uint end, address admin, bool isMultipleChoices) {
    require(campaignID < numberCampaigns);
    uint campInfo = campaigns[campaignID].info;
    end = (campInfo & CAMP_END_TIME_MASK) >> 4;
    isMultipleChoices = (campInfo & CAMP_IS_MULTI_CHOICES_MASK) == 1;
    return (
      campaigns[campaignID].title,
      end,
      campaigns[campaignID].admin,
      isMultipleChoices
    );
  }

  // check if an address is whitelisted, allow all access
  function checkWhitelisted(uint campaignID, address _account) public view returns (bool isWhitelisted) {
    return campaigns[campaignID].whitelistedAddresses[_account] == true;
  }

  // get options count for a given campaignID
  function getOptionsCount(uint campaignID) public view returns (uint count) {
    require(campaignID < numberCampaigns);
    return (campaigns[campaignID].info & CAMP_OPTION_COUNT_MASK) >> 128;
  }

  // func get list of options for a given campaignID (ids, names, urls)
  // return 3 arrays with list data of option IDs, option names, option URLs
  function getListOptions(uint campaignID) public view returns (uint[] memory ids, bytes32[] memory names, bytes32[] memory urls) {
    require(campaignID < numberCampaigns);
    uint count = (campaigns[campaignID].info & CAMP_OPTION_COUNT_MASK) >> 128;
    ids = new uint[](count);
    names = new bytes32[](count);
    urls = new bytes32[](count);
    uint campIDMask = campaignID << 128;
    for (uint i = 0; i < count; i++) {
      Option storage op = options[i | campIDMask];
      ids[i] = i;
      names[i] = op.name;
      urls[i] = op.url;
    }
    return (ids, names, urls);
  }

  // get fully details of an option given mergedID (its ID and campaignID), (name, url, voters)
  function getOption(uint mergedID) public view returns (bytes32 name, bytes32 url, address[] voters) {
    uint campaignID = (mergedID & CAMP_ID_MASK) >> 128;
    uint optionID = mergedID & OPTION_ID_MASK;
    require(campaignID < numberCampaigns);
    require(optionID < (campaigns[campaignID].info & CAMP_OPTION_COUNT_MASK) >> 128);
    return (
      options[mergedID].name,
      options[mergedID].url,
      options[mergedID].voters
    );
  }

  // option function return list of voters for given mergedID of scampaignID and optionID
  // mostly option data is not changed, but list voters is changing over time
  // getting fully details is redundant, (voters)
  function getVoters(uint mergedID) public view returns (address[] voters) {
    uint campaignID = (mergedID & CAMP_ID_MASK) >> 128;
    uint optionID = mergedID & OPTION_ID_MASK;
    require(campaignID < numberCampaigns);
    require(optionID < (campaigns[campaignID].info & CAMP_OPTION_COUNT_MASK) >> 128);
    return options[mergedID].voters;
  }

  // return total number of all campaigns
  function getTotalNumberCampaigns() public view returns (uint count) {
    return numberCampaigns;
  }

  // Getting index of an element in the array, return length of array if element is not in the array
  function getIndexOfElementInArray(address[] memory array, address element) internal pure returns (uint index) {
    for(uint i = 0; i < array.length; i++) {
      if (array[i] == element) { return i; }
    }
    return array.length;
  }
}
