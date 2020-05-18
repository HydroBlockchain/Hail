const truffleAssert = require('truffle-assertions')
const SnowflakeOwnable = artifacts.require('./components/SnowflakeOwnable.sol')
const utilities = require('./utilities')
const common = require('./common.js')

// all contracts
let instances
// all users
let users
// system owner and deployer (same as users[0])
let owner

let ownerEIN

contract('Testing SnowflakeOwnable', function (accounts) {

  it('Users created', async () => {
    users = await common.createUsers(accounts);
    owner = users[0];
  })
  
  it('Common contracts deployed', async () => {
    instances = await common.initialize(owner.address, users);
  })

  it('Snowflake identities created for all accounts', async() => {
    for (let i = 0; i < users.length; i++) {
      await utilities.createIdentity(users[i], instances, {from: owner.address});
    }
  })


  describe('Checking IdentityRegistry functionality', async() =>{

    // Try to create duplicate identity
    it('IdentityRegistry create Identity (exists, should revert)', async () => {
      await truffleAssert.reverts(
        instances.IdentityRegistry.createIdentity(
          users[1].address,
          accounts,
          accounts,
          {from: users[0].address}),
          'The passed address has an identity but should not..'
      )
    })

    // Retrieve EIN for an Identity from IdentityRegistry
    it('IdentityRegistry retrieve EIN', async () => {
      _ein = await instances.IdentityRegistry.getEIN(
        users[1].address,
        //{from: users[0].address}
      )
      console.log('      EIN users[1]', _ein)
    })

  })


  describe('Checking SnowflakeOwnable functionality', async() =>{

    // Create SnowflakeOwnable contract
    it('SnowflakeOwnable can be created', async () => {
      newSnowflakeOwnable = await SnowflakeOwnable.new(
        {from: users[1].address}
      )
        console.log('      SnowflakeOwnable Address', newSnowflakeOwnable.address)
        console.log('      users[1]', users[1].address)
    })

    it('SnowflakeOwnable exists', async () => {
      ownerEIN = await newSnowflakeOwnable.ownerEIN()//{from: users[1].address})
      console.log('      Owner EIN', ownerEIN)
    })

    it('SnowflakeOwnable set Identity Registry', async () => {
      console.log('      Identity Registry Address', instances.IdentityRegistry.address)
      await newSnowflakeOwnable.setIdentityRegistryAddress(
        instances.IdentityRegistry.address,
        {from: users[1].address}
      )
    })

    it('SnowflakeOwnable get Identity Registry Address', async () => {
      _snowIDaddress = await newSnowflakeOwnable.getIdentityRegistryAddress(
        //{from: users[1].address}
      )
      console.log('      snowflake ownable identity registry address', _snowIDaddress)
    })

    it('SnowflakeOwnable get owner EIN', async () => {
      ownerEIN = await newSnowflakeOwnable.getOwnerEIN(
        //{from: users[1].address}
      )
      console.log('      snowflake ownable owner EIN', ownerEIN)
    })

    // Try to transfer ownership to an identity which does not exist
    // owner is users[0]
    it('Snowflake ownable transfer ownership (no identity, should revert)', async () => {
      await truffleAssert.reverts(
        newSnowflakeOwnable.setOwnerEIN(
          21,
          {from: users[1].address}),
          'New owner identity must exist'
      )
    })

    it('SnowflakeOwnable get owner EIN', async () => {
      ownerEIN = await newSnowflakeOwnable.getOwnerEIN(
        //{from: users[1].address}
      )
      console.log('      snowflake ownable new owner EIN after transfer 1', ownerEIN)
    })

    // Try to transfer ownership without being the owner
    // owner is users[1]
    it('Snowflake ownable transfer ownership (not the owner, should revert)', async () => {
      _ein = await instances.IdentityRegistry.getEIN(
        users[3].address,
        //{from: users[2].address}
      )
      console.log('      EIN users[3]', _ein)
      await truffleAssert.reverts(
        newSnowflakeOwnable.setOwnerEIN(
          _ein,
          {from: users[2].address}),
          'Must be the EIN owner to call this function'
      )
    })

    it('SnowflakeOwnable get owner EIN', async () => {
      ownerEIN = await newSnowflakeOwnable.getOwnerEIN(
        //{from: users[1].address}
      )
      console.log('      snowflake ownable new owner EIN after transfer 2', ownerEIN)
    })

    // Transfer ownership being the owner
    // owner is users[0]
    it('Snowflake ownable transfer ownership', async () => {
      await newSnowflakeOwnable.setOwnerEIN(
        9,
        {from: users[1].address}
      )
    })

    it('SnowflakeOwnable get owner EIN', async () => {
      ownerEIN = await newSnowflakeOwnable.getOwnerEIN(
        //{from: users[1].address}
      )
      console.log('      snowflake ownable new owner EIN after transfer 3', ownerEIN)
    })

  })

})
