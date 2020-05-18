const ClientRaindrop = artifacts.require('./resolvers/ClientRaindrop/ClientRaindrop.sol')
const DateTime = artifacts.require('./components/DateTime.sol')
const HydroToken = artifacts.require('./_testing/HydroToken.sol')
const HSTBuyerRegistry = artifacts.require('./components/HSTBuyerRegistry.sol')
const HSTokenRegistry = artifacts.require('./components/HSTokenRegistry.sol')
const HSTServiceRegistry = artifacts.require('./components/HSTServiceRegistry.sol')
const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')
const KYCResolver = artifacts.require('./samples/KYCResolver.sol')
const OldClientRaindrop = artifacts.require('./_testing/OldClientRaindrop.sol')
const Snowflake = artifacts.require('./Snowflake.sol')


async function createUsers (accounts) {
  const users = [
    // system owner
    {
      hydroID: 'own',
      address: accounts[0],
      recoveryAddress: accounts[0],
      private: '0xae3e306946509ed8b16ef2164537c8ab00338eaf2790a342af41c32f4f8897c6',
      id: 1,
      identity: 0,
      ein: 0 // 1
    },
    // buyer A
    {
      hydroID: 'fir',
      address: accounts[1],
      recoveryAddress: accounts[1],
      private: '0x8ea994d52a042bce97741bab4bd7ac669b985c49459139837df04cdf481fe290',
      id: 2,
      identity: 0,
      ein: 0 // 2
    },
    // buyer B
    {
      hydroID: 'sec',
      address: accounts[2],
      recoveryAddress: accounts[2],
      private: '0xe2d20428b94388902bacbba3e3a3e69d9024e45a8d4fa8f5e9b1348cfb953c3c',
      id: 3,
      identity: 0,
      ein: 0 // 3
    },
    {
      hydroID: 'thi',
      address: accounts[3],
      recoveryAddress: accounts[3],
      private: '0x76b9be39e7cc525ee53b91b1aaa5b3e284eb2d6994a190fdf7a30b87bf6e56d6',
      id: 4,
      identity: 0,
      ein: 0 // 4
    },
    {
      hydroID: 'fou',
      address: accounts[4],
      recoveryAddress: accounts[4],
      private: '0x4a6ee7599b26cd6b39c2ea2c2de126ce8eee088090d62265889884387ccf2ea2',
      id: 5,
      identity: 0,
      ein: 0 // 5
    },
    {
      hydroID: 'fif',
      address: accounts[5],
      recoveryAddress: accounts[5],
      private: '0x9e4ab61a4b29cc679981efb4748c6ec2de17200a62fb1d882e4b1ac4ecca6a93',
      id: 6,
      identity: 0,
      ein: 0 // 6
    },
    {
      hydroID: 'six',
      address: accounts[6],
      recoveryAddress: accounts[6],
      private: '0x7f6f7ca60c9db88f09aacfe371f46de7b5c094cba1dc8f9e763276b980ebff90',
      id: 7,
      identity: 0,
      ein: 0 // 7
    },
    {
      hydroID: 'sev',
      address: accounts[7],
      recoveryAddress: accounts[7],
      private: '0x4e327aab54f780303a93ac02bad4002172a8d9f3a8d51a422cbff2db92da9908',
      id: 8,
      identity: 0,
      ein: 0 // 8
    },
    // kyc service provider
    {
      hydroID: 'eig',
      address: accounts[8],
      recoveryAddress: accounts[8],
      private: '0x353a17890673fe618532977eda16f6f3caf2cf67bb678c6fa39c03c64abcc2e8',
      id: 9,
      identity: 0,
      ein: 0 // 9
    },
    // token owner
    {
      hydroID: 'nin',
      address: accounts[9],
      recoveryAddress: accounts[9],
      private: '0xe68a092b21338e8dc378c322a2cc0bc3fbb9ddc5a50781018825430a7b60e413',
      id: 10,
      identity: 0,
      ein: 0 // 10
    }
  ]
  return users;
}


async function initialize (systemOwnerAddress, users) {

  const instances = {} // all contracts

  instances.DateTime = await DateTime.new( { from: systemOwnerAddress })
  console.log("    common - Date Time", instances.DateTime.address)

  instances.HydroToken = await HydroToken.new({ from: systemOwnerAddress })
  console.log("    common - Hydro Token", instances.HydroToken.address)

  for (let i = 0; i < users.length; i++) {
    await instances.HydroToken.transfer(
      users[i].address,
      web3.utils.toBN(1000).mul(web3.utils.toBN(1e18)),
      { from: systemOwnerAddress }
    )
  }

  instances.IdentityRegistry = await IdentityRegistry.new({ from: systemOwnerAddress })
  console.log("    common - Identity Registry", instances.IdentityRegistry.address)

  instances.Snowflake = await Snowflake.new(
    instances.IdentityRegistry.address, instances.HydroToken.address, { from: systemOwnerAddress }
  )
  console.log("    common - Snowflake", instances.Snowflake.address)

  instances.OldClientRaindrop = await OldClientRaindrop.new({ from: systemOwnerAddress })
  console.log("    common - Old Client Raindrop", instances.OldClientRaindrop.address)

  instances.ClientRaindrop = await ClientRaindrop.new(
    instances.Snowflake.address, instances.OldClientRaindrop.address, 0, 0, { from: systemOwnerAddress }
  )
  await instances.Snowflake.setClientRaindropAddress(
    instances.ClientRaindrop.address, { from: systemOwnerAddress }
  )
  console.log("    common - Client Raindrop", instances.ClientRaindrop.address)

  instances.KYCResolver = await KYCResolver.new( {from: systemOwnerAddress })
  console.log("    common - KYC Resolver", instances.KYCResolver.address)

  instances.BuyerRegistry = await HSTBuyerRegistry.new(
    instances.DateTime.address, { from: systemOwnerAddress }
  )
  console.log("    common - Buyer Registry", instances.BuyerRegistry.address)

  instances.TokenRegistry = await HSTokenRegistry.new( { from: systemOwnerAddress } )
  console.log("    common - Token Registry", instances.TokenRegistry.address)

  instances.ServiceRegistry = await HSTServiceRegistry.new( { from: systemOwnerAddress } )
  console.log("    common - Service Registry", instances.ServiceRegistry.address)


  await instances.ServiceRegistry.setAddresses(
    instances.IdentityRegistry.address,
    instances.TokenRegistry.address,
    { from: systemOwnerAddress }
  )
  // await instances.ServiceRegistry.setIdentityRegistryAddress(
  //   instances.IdentityRegistry.address,
  //   { from: systemOwnerAddress }
  // )

  await instances.TokenRegistry.setAddresses(
    instances.IdentityRegistry.address,
    instances.ServiceRegistry.address,
    { from: systemOwnerAddress }
  )
  // await instances.TokenRegistry.setIdentityRegistryAddress(
  //   instances.IdentityRegistry.address,
  //   { from: systemOwnerAddress }
  // )
  
  await instances.BuyerRegistry.setAddresses(
    instances.IdentityRegistry.address,
    instances.TokenRegistry.address,
    instances.ServiceRegistry.address,
    { from: systemOwnerAddress }
  )
  // await instances.BuyerRegistry.setIdentityRegistryAddress(
  //   instances.IdentityRegistry.address,
  //   { from: systemOwnerAddress }
  // )

  console.log("    common - finishing and returning instances")

  return instances
}


module.exports = {
  createUsers: createUsers,
  initialize: initialize
}
