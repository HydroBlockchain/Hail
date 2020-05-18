console.log(accounts)
const HSTIssuer = artifacts.require('./HSTIssuer.sol')


module.exports = async function(deployer) {
	console.log(accounts);
	console.log("1");

	await deployer.deploy(HSTIssuer,
		1,
		"0xa7f15e4e66334e8214dfd97d5214f1f8f11c90f25bbe44b344944ed9efed7e29",
		"Hydro Security token for testing purposes",
		"HTST",
		18,
		"0x4959c7f62051D6b2ed6EaeD3AAeE1F961B145F20", // HydroToken Rinkeby
		"0xa7ba71305bE9b2DFEad947dc0E5730BA2ABd28EA" // IdentityRegistry Rinkeby
		)
  	console.log("2");
};
