var Voting = artifacts.require('Voting');
var KyVote = artifacts.require('KyVote');

module.exports = function (deployer) {
  deployer.deploy(Voting)
  deployer.deploy(KyVote)
}
