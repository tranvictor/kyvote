// Import the page's CSS. Webpack will know what to do with it.
import '../styles/app.css'

// Import libraries we need.
import { default as Web3 } from 'web3'
import { default as contract } from 'truffle-contract'

// The following code is simple to show off interacting with your contracts.
// As your needs grow you will likely need to change its form and structure.
// For application bootstrapping, check out window.addEventListener below.

// import votingArtifact from '../../build/contracts/Voting.json';
// const Voting = contract(votingArtifact);

const App = {
  web3Provider: null,
  contracts: {},

  init: function () {
    console.log('Init App');
    return App.initWeb3();
  },

  initWeb3: function() {
    console.log('Init web3');
    // Is there an injected web3 instance?
    if (typeof web3 !== 'undefined') {
      console.log('Already had web3');
      App.web3Provider = web3.currentProvider;
    } else {
      console.log('Create web3');
      // If no injected web3 instance is detected, fall back to Ganache
      App.web3Provider = new Web3.providers.HttpProvider('http://localhost:7545');
    }
    web3 = new Web3(App.web3Provider);
    $.getJSON('../../build/contracts/Voting.json', function(data) {
      var votingArtifact = data;
      App.contracts.Voting = TruffleContract(votingArtifact);
      App.contracts.Voting.setProvider(App.web3Provider);
      App.getNumberOptions();
      App.bindEvents();
    });
  },

  setStatus: function (message) {
    const status = document.getElementById('status');
    status.innerHTML = message;
  },

  vote: function () {
    const self = this;

    const userName = web3.fromAscii(document.getElementById('username').value);
    const optionID = parseInt(document.getElementById('optionid').value);

    console.log("Voting for option ID: " + optionID);

    App.setStatus('Initiating transaction... (please wait)')

    let votingInstance;
    web3.eth.getAccounts(function(error, accounts) {
      if (error) {
        console.log(error);
      }

      var account = accounts[0];
      console.log('Number of accounts: ' + accounts.length);
      App.contracts.Voting.deployed().then(function(instance) {
        votingInstance = instance;
        return votingInstance.vote(userName, optionID, {from: account});
      }).then(function () {
        App.setStatus('Successfully voted!');
        App.getNumberVoters();
      }).catch(function (e) {
        console.log(e);
        App.setStatus('Error add option see log.');
      });
    });
  },

  getNumberVoters: function (optionID) {
    let votingInstance;
    App.contracts.Voting.deployed().then(function (instance) {
      votingInstance = instance;
      return votingInstance.getNumberVoters();
    }).then(function (value) {
      App.setStatus('Number voters: ' + value);
    }).catch(function (e) {
      console.log(e);
      App.setStatus('Error get number votes see log.');
    });
  },

  displayNumberVotes: function () {
    const optionID = parseInt(document.getElementById('numbervotesoptionid').value);
    console.log("Get number votes for option ID: " + optionID);

    let votingInstance;
    App.setStatus('Initiating transaction... (please wait)');
    App.contracts.Voting.deployed().then(function (instance) {
      votingInstance = instance;
      return votingInstance.totalVotes(optionID);
    }).then(function (value) {
      App.setStatus('Number votes for option ID: ' + optionID + " is " + value);
    }).catch(function (e) {
      console.log(e);
      App.setStatus('Error get number votes see log.');
    });
  },

  bindEvents: function() {
    console.log('clicked');
    $(document).on('click', '.btn-vote', App.vote);
    $(document).on('click', '.btn-add-option', App.addOption);
    $(document).on('click', '.btn-remove-option', App.removeOption);
    $(document).on('click', '.btn-get-number-votes', App.displayNumberVotes);
  },

  getNumberOptions: function () {
    console.log("Getting number options");
    let votingInstance;
    App.contracts.Voting.deployed().then(function (instance) {
      console.log("Voting deployed");
      votingInstance = instance
      return votingInstance.getNumberOptions();
    }).then(function (value) {
      App.setStatus('Number options: ' + value);
    }).catch(function (e) {
      console.log(e);
      App.setStatus('Error get number options see log.');
    });
  },

  addOption: function () {
    console.log("Adding option");
    const self = this;

    const optionName = web3.fromAscii(document.getElementById('optionname').value);
    const optionDesc = web3.fromAscii(document.getElementById('optiondesc').value);

    App.setStatus('Initiating transaction... (please wait)');

    let votingInstance;
    web3.eth.getAccounts(function(error, accounts) {
      if (error) { console.log(error); }

      var account = accounts[0];
      App.contracts.Voting.deployed().then(function (instance) {
        votingInstance = instance;
        return votingInstance.addOption(optionName, optionDesc, {from: account});
      }).then(function(value) {
        console.log('Add option successfully!');
        App.setStatus('Add option successfully!');
      }).catch(function (e) {
        console.log(e);
        App.setStatus('Error add option see log.');
      });
    });
  },

  removeOption: function () {
    console.log("Removing option");
    const optionID = parseInt(document.getElementById('removeoptionid').value);

    App.setStatus('Initiating transaction... (please wait)');

    let votingInstance;
    web3.eth.getAccounts(function(error, accounts) {
      if (error) { console.log(error); }
      var account = accounts[0];
      App.contracts.Voting.deployed().then(function (instance) {
        votingInstance = instance;
        return votingInstance.removeOption(optionID, {from: account});
      }).then(function() {
        console.log('Remove option successfully!');
        App.setStatus('Removed option successfully!');
      }).catch(function (e) {
        console.log(e);
        App.setStatus('Error remove option see log.');
      });
    });
  },
};

window.App = App;

window.addEventListener('load', function () {
  App.init();
})
