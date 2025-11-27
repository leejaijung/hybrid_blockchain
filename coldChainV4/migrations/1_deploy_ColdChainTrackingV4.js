const ColdChainTrakingV4 = artifacts.require("ColdChainTrakingV4");

module.exports = function(deployer) {
    deployer.deploy(ColdChainTrakingV4);
};