pragma solidity ^0.4.18;

contract Voting {

  // an event that is called when an Option is added
  event AddedOption(uint optionID);

  // a voter, has id and the ids of option that they voted
  struct Voter {
    bytes32 uid;
    uint optionIDVote;
  }

  // an Option
  struct Option {
    bytes32 name;
    bytes32 desc;
    bool doesExist;
  }

  uint numberOptions;
  uint numberVoters;

  mapping (uint => Option) options;
  mapping (uint => Voter) voters;

  function addOption(bytes32 name, bytes32 desc) public returns (uint) {
    uint optionID = numberOptions++;
    options[optionID] = Option(name, desc, true);
    return optionID;
  }

  function removeOption(uint optionID) public {
    require(optionID >= 0 && optionID < numberOptions);
    require(options[optionID].doesExist == true);
    options[optionID].doesExist = false;
  }

  function vote(bytes32 uid, uint optionID) public {
    require(optionID >= 0 && optionID < numberOptions);
    if (options[optionID].doesExist == true) {
      uint voterID = numberVoters++;
      voters[voterID] = Voter(uid, optionID);
    }
  }

  function totalVotes(uint optionID) public view returns (uint) {
    require(optionID >= 0 && optionID < numberOptions);
    uint voteCount = 0;
    for (uint i = 0; i < numberVoters; i++) {
      if (voters[i].optionIDVote == optionID) {
        voteCount++;
      }
    }
    return voteCount;
  }

  function getExistedOptions() public view returns (uint) {
    uint existedOptions = 0;
    for (uint i = 0; i < numberOptions; i++) {
      if (options[i].doesExist == true) {
        existedOptions++;
      }
    }
    return existedOptions;
  }

  function getNumberOptions() public view returns (uint) {
    return numberOptions;
  }

  function getNumberVoters() public view returns (uint) {
    return numberVoters;
  }

  function getOption(uint optionID) public view returns (uint, bytes32, bytes32) {
    require(optionID >= 0 && optionID < numberOptions);
    return (optionID, options[optionID].name, options[optionID].desc);
  }
}
