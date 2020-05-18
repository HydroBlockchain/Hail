const ethUtil = require('ethereumjs-util')

function sign (messageHash, address, privateKey, method) {
  return new Promise(resolve => {
    if (method === 'prefixed') {
      web3.eth.sign(messageHash, address)
        .then(concatenatedSignature => {
          let strippedSignature = ethUtil.stripHexPrefix(concatenatedSignature)
          let signature = {
            r: ethUtil.addHexPrefix(strippedSignature.substr(0, 64)),
            s: ethUtil.addHexPrefix(strippedSignature.substr(64, 64)),
            v: parseInt(ethUtil.addHexPrefix(strippedSignature.substr(128, 2))) + 27
          }
          resolve(signature)
        })
    } else {
      let signature = ethUtil.ecsign(
        Buffer.from(ethUtil.stripHexPrefix(messageHash), 'hex'),
        Buffer.from(ethUtil.stripHexPrefix(privateKey), 'hex')
      )
      signature.r = ethUtil.bufferToHex(signature.r)
      signature.s = ethUtil.bufferToHex(signature.s)
      signature.v = parseInt(ethUtil.bufferToHex(signature.v))
      resolve(signature)
    }
  })
}

function timeTravel (seconds) {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [seconds],
      id: new Date().getTime()
    }, (err, result) => {
      if (err) return reject(err)
      return resolve(result)
    })
  })
}

async function verifyIdentity (ein, IdentityRegistry, expectedIdentity) {
  const identityExists = await IdentityRegistry.identityExists(ein)
  assert.isTrue(identityExists, "identity unexpectedly does/doesn't exist.")

  for (const address of expectedIdentity.associatedAddresses) {
    const hasIdentity = await IdentityRegistry.hasIdentity(address)
    assert.isTrue(hasIdentity, "address unexpectedly doesn't have an identity.")

    const onChainIdentity = await IdentityRegistry.getEIN(address)
    assert.isTrue(onChainIdentity.eq(ein), 'on chain identity was set incorrectly.')

    const isAssociatedAddressFor = await IdentityRegistry.isAssociatedAddressFor(ein, address)
    assert.isTrue(isAssociatedAddressFor, 'associated address was set incorrectly.')
  }

  for (const provider of expectedIdentity.providers) {
    const isProviderFor = await IdentityRegistry.isProviderFor(ein, provider)
    assert.isTrue(isProviderFor, 'provider was set incorrectly.')
  }

  for (const resolver of expectedIdentity.resolvers) {
    const isResolverFor = await IdentityRegistry.isResolverFor(ein, resolver)
    assert.isTrue(isResolverFor, 'associated resolver was set incorrectly.')
  }

  const identity = await IdentityRegistry.getIdentity(ein)
  assert.equal(identity.recoveryAddress, expectedIdentity.recoveryAddress, 'unexpected recovery address.')
  assert.deepEqual(identity.associatedAddresses, expectedIdentity.associatedAddresses, 'unexpected associated addresses.')
  assert.deepEqual(identity.providers, expectedIdentity.providers, 'unexpected providers.')
  assert.deepEqual(identity.resolvers, expectedIdentity.resolvers, 'unexpected resolvers.')
}


const createIdentity = async(_user, instances) => {
//async function createIdentity (_user, instances) {

    const timestamp = Math.round(new Date() / 1000) - 1
    const permissionString = web3.utils.soliditySha3(
      '0x19', '0x00', instances.IdentityRegistry.address,
      'I authorize the creation of an Identity on my behalf.',
      _user.recoveryAddress,
      _user.address,
      { t: 'address[]', v: [instances.Snowflake.address] },
      { t: 'address[]', v: [] },
      timestamp
    )

    const permission = await sign(permissionString, _user.address, _user.private)

    await instances.Snowflake.createIdentityDelegated(
      _user.recoveryAddress, _user.address, [], _user.hydroID, permission.v, permission.r, permission.s, timestamp, {from: _user.address}
    )

    _user.identity = web3.utils.toBN(_user.id)

    await verifyIdentity(_user.identity, instances.IdentityRegistry, {
      recoveryAddress:     _user.recoveryAddress,
      associatedAddresses: [_user.address],
      providers:           [instances.Snowflake.address],
      resolvers:           [instances.ClientRaindrop.address]
    })

}


function daysOn(_days) {
  return parseInt(new Date() / 1000 + daysToSeconds(_days)).toString();
}

function daysToSeconds(_days) {
  return _days * 24 * 60 * 60;
}


module.exports = {
  sign: sign,
  timeTravel: timeTravel,
  verifyIdentity: verifyIdentity,
  daysOn: daysOn,
  daysToSeconds: daysToSeconds,
  createIdentity: createIdentity
}
