pragma solidity ^0.4.18;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Voting.sol";

contract TestVoting {

  function testAddAnOption() public {
    Voting voting = Voting(DeployedAddresses.Voting());
    uint numberOptions = voting.getNumberOptions();
    voting.addOption(bytes32("New Option"), bytes32("New Description"));
    Assert.equal(numberOptions + 1, voting.getNumberOptions(), "Should added new option successfully!");
  }

  function testVote() public {
    Voting voting = Voting(DeployedAddresses.Voting());
    voting.addOption(bytes32("New Option"), bytes32("New Description"));
    uint numberOptions = voting.getNumberOptions();
    uint numberVotes = voting.totalVotes(numberOptions - 1);
    voting.vote(bytes32("Mike Le"), numberOptions - 1);
    Assert.equal(numberVotes + 1, voting.totalVotes(numberOptions - 1), "Number votes should be increased by one");
  }

  function testNumberVoters() public {
    Voting voting = Voting(DeployedAddresses.Voting());
    voting.addOption(bytes32("New Option"), bytes32("New Description"));
    uint numberOptions = voting.getNumberOptions();
    uint numberVoters = voting.getNumberVoters();
    voting.vote(bytes32("Mike Le"), numberOptions - 1);
    Assert.equal(numberVoters + 1, voting.getNumberVoters(), "Number voters should be increased by one");
  }

  function testGetNewAddedOptions() public {
    Voting voting = Voting(DeployedAddresses.Voting());
    bytes32 name = bytes32("New Option");
    bytes32 desc = bytes32("New Description");
    voting.addOption(name, desc);
    uint numberOptions = voting.getNumberOptions();
    (uint optionID, bytes32 optionName, bytes32 optionDesc) = voting.getOption(numberOptions - 1);
    Assert.equal(optionID, numberOptions - 1, "Incorrect option id");
    Assert.equal(optionName, name, "Incorrect option name");
    Assert.equal(optionDesc, desc, "Incorrect option desc");
  }

  function removeAnOption() public {
    Voting voting = Voting(DeployedAddresses.Voting());
    voting.addOption(bytes32("New Option"), bytes32("New Description"));
    uint existedOptions = voting.getExistedOptions();
    voting.removeOption(existedOptions - 1);
    Assert.equal(existedOptions - 1, voting.getExistedOptions(), "Removed an option failed!");
  }
}
