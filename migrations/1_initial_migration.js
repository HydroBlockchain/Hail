const HSToken = artifacts.require('./HSToken.sol')
const AddressSet = artifacts.require('./_testing/AddressSet/AddressSet.sol')
const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')

const HydroToken = artifacts.require('./_testing/HydroToken.sol')

const SafeMath = artifacts.require('./zeppelin/math/SafeMath.sol')
const Ownable = artifacts.require('./zeppelin/math/Ownable.sol')
const Snowflake = artifacts.require('./Snowflake.sol')
// const Status = artifacts.require('./resolvers/Status.sol')

const StringUtils = artifacts.require('./resolvers/ClientRaindrop/StringUtils.sol')
const ClientRaindrop = artifacts.require('./resolvers/ClientRaindrop/ClientRaindrop.sol')
const OldClientRaindrop = artifacts.require('./_testing/OldClientRaindrop.sol')


module.exports = async function(deployer, network) {


	await deployer.deploy(AddressSet)
  await deployer.link(AddressSet, IdentityRegistry)


  await deployer.deploy(StringUtils)
  await deployer.link(StringUtils, ClientRaindrop)
  await deployer.link(StringUtils, OldClientRaindrop)

  await deployer.deploy(SafeMath)
  await deployer.link(SafeMath, HydroToken)
  await deployer.link(SafeMath, Snowflake)


  await deployer.deploy(Ownable)

  await deployer.deploy(HydroToken)
  await deployer.deploy(IdentityRegistry)
	
console.log("SafeMath:", SafeMath.address);
console.log("HydroToken:",HydroToken.address);

console.log("Network:",network);

var HydroTokenAdd
var IdentityRegistryAdd

if (network == "development") {
	HydroTokenAdd = HydroToken.address
	IdentityRegistryAdd = IdentityRegistry.address
	console.log("DEV",HydroTokenAdd,IdentityRegistryAdd )

} else {
	HydroTokenAdd = "0x4959c7f62051d6b2ed6eaed3aaee1f961b145f20";
	IdentityRegistryAdd = "0xa7ba71305be9b2dfead947dc0e5730ba2abd28ea";
	console.log("RINK",HydroTokenAdd,IdentityRegistryAdd )
}

const deployToken = async () => {
	await deployer.deploy(HSToken,
		1,
		"0x12afe",
		"Hydro Security",
		"HTST",
		18,
		HydroTokenAdd, // HydroToken Rinkeby
		IdentityRegistryAdd // IdentityRegistry Rinkeby
		)

	console.log("HSToken Address", HSToken.address);
 	}



  	//await  deployer.link(SafeMath, HSToken)
  	//await  deployer.link(Ownable, HSToken)

};
