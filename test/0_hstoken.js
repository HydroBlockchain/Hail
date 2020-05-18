const HSToken = artifacts.require('./HSToken.sol')

const truffleAssert = require('truffle-assertions')
const common = require('./common.js')
const utilities = require('./utilities')

let instances // all contracts
let users // all users
let owner // system deployer and owner


const sleep = async(_seconds) => {
  await new Promise(resolve => setTimeout(resolve, _seconds * 1000));
}

contract('Testing HSToken', function (accounts) {

  it('Users created', async () => {
      users = await common.createUsers(accounts);
      owner = users[0];
    })

console.log(users)

  it('common contracts deployed', async () => {
    instances = await common.initialize(users[0].address, users)
  })


  it('Snowflake identities created for all accounts', async() => {
    for (let i = 0; i < users.length; i++) {
      await utilities.createIdentity(users[i], instances)
    }
  })


/*  it('Snowflake identities created for owner', async() => {
    for (let i = 0; i < users.length; i++) {
      await createIdentity(users[3], instances)
    }
  })*/


  describe('Checking HSToken functionality (SHARES)', async() =>{


    it('HSToken can be created', async () => {

      newToken = await HSToken.new(
          1, // Token Id
          0, // STO Type (0: Shares, 1: Units, 2: Bonds)
          web3.utils.stringToHex("HydroSecurityToken"), // Name
          "Hydro Security", // Description
          web3.utils.fromAscii("HTST"), // Symbol
          18, // Decimals
          instances.HydroToken.address, // HydroToken address
          instances.IdentityRegistry.address, // IdentityRegistry address
          instances.BuyerRegistry.address, // BuyerRegistry address
          users[9].address, // Owner address (Ein owner will be taken from this)
          {from: users[9].address}
        )

        receipt = await web3.eth.getTransactionReceipt(newToken.transactionHash);
        console.log("      Gas used: ", receipt.gasUsed);
        console.log("      HSToken Address", newToken.address)
        console.log("      Token owner", users[9].address)
    })
    
    it('HSToken exists', async () => {
      userId = await newToken.isTokenAlive();
    })

    it('Appoint token', async () => {
      await instances.TokenRegistry.appointToken(
        newToken.address, // token address
        web3.utils.fromAscii('HTST'), // token symbol
        web3.utils.fromAscii('Hydro Security'), // token name
        'just-a-test', // token description
        18, // token decimals
        {from: users[9].address} // will be assigned as token owner in token registry
      )
    })


    // ------------------------------ BuyerRegistry settings

    it('Set default values to BuyerRegistry', async () => {
      instances.BuyerRegistry.assignTokenValues(
        newToken.address, // token address
        '21', // minimum age
        '50000', // minimum net worth
        '36000', // minimum salary
        false, // accredited investor status required
        false, // aml whitelisting required
        false, // cft whitelisting required
        {from: users[9].address} // must be (and it is) the token owner
        )
    })

    it('HSTBuyerRegistry - add buyer 1', async () => {
      await instances.BuyerRegistry.addBuyer(
        '2', // EIN
        'Johnny', // first name
        'Tester', // last name
        web3.utils.fromAscii('GMB'),
        '1984', // year of birth
        '12', // month of birth
        '12', // day of birth
        '100000', // net worth
        '50000', // salary
        {from: users[9].address} // can be any registered token owner
      )
    })


    it('HSTBuyerRegistry - add buyer 2', async () => {
      await instances.BuyerRegistry.addBuyer(
        '3', // EIN
        'Peter', // first name
        'Tester', // last name
        web3.utils.fromAscii('GMB'),
        '1980', // year of birth
        '10', // month of birth
        '20', // day of birth
        '100000', // net worth
        '50000', // salary
        {from: users[9].address} // can be any registered token owner
      )
    })

    it('HSTServiceRegistry - add legal advisor', async () => {
      await instances.ServiceRegistry.addService(
        newToken.address, // token address
        '8', // service provider EIN (user 7)
        web3.utils.fromAscii("MLA"), // category symbol
        {from: users[9].address} // must be (and it is) the token owner
      )
    })


    it('Grant legal approval for token', async () => {
      await instances.TokenRegistry.grantLegalApproval(
        newToken.address, // token address
        {from: users[7].address} // Legal advisor provider (setted in previous test)
      )
    })


    it('HSTServiceRegistry - add service', async () => {
      await instances.ServiceRegistry.addService(
        newToken.address, // token address
        '9', // service provider EIN
        web3.utils.fromAscii("KYC"), // category symbol
        {from: users[9].address} // must be (and it is) the token owner
      )
    })

    it('HSTServiceRegistry - get service', async () => {
      _serviceCategory = await instances.ServiceRegistry.getService(
        newToken.address, // token address
        '9', // service provider EIN
        {from: users[9].address}
      )
      console.log("      HSTServiceRegistry service", web3.utils.toAscii(_serviceCategory))
    })

    it('IdentityRegistry - get EIN for KYC provider', async () => {
      _kycProviderEin = await instances.IdentityRegistry.getEIN(
        users[8].address, // kyc provider address
        {from: users[9].address} // token owner
      )
      console.log("      Kyc provider users[8] ein from identity registry", _kycProviderEin)
    })

    it('HSTBuyerRegistry - add kyc service for buyer 1', async () => {
      await instances.BuyerRegistry.addKycServiceToBuyer(
        '2', // buyer EIN
        newToken.address, // token address
        '9', // service provider EIN
        {from: users[9].address} // token owner
      )
      console.log("      Users[8] EIN", users[8].ein)
    })

    it('HSTBuyerRegistry - get kyc service for buyer 1', async () => {
      _kycProviderForBuyer = await instances.BuyerRegistry.getKycServiceForBuyer(
        '2', // buyer EIN
        newToken.address, // token address
        {from: users[9].address} // token owner
      )
      console.log("      HSTBuyerRegistry kyc service", _kycProviderForBuyer)
    })

    it('HSTBuyerRegistry - add kyc service for buyer 2', async () => {
      await instances.BuyerRegistry.addKycServiceToBuyer(
        '3', // buyer EIN
        newToken.address, // token address
        '9', // service provider EIN
        {from: users[9].address} // token owner
      )
      console.log("      Users[8] EIN", users[8].ein)
    })

    it('HSTBuyerRegistry - get kyc service for buyer 2', async () => {
      _kycProviderForBuyer = await instances.BuyerRegistry.getKycServiceForBuyer(
        '3', // buyer EIN
        newToken.address, // token address
        {from: users[9].address} // token owner
      )
      console.log("      HSTBuyerRegistry kyc service", _kycProviderForBuyer)
    })

    it('HSToken set MAIN_PARAMS', async () => {
      console.log("      Startconfiguring token")
      await newToken.set_MAIN_PARAMS(
        web3.utils.toWei("0.1"), // hydroPrice: 1 ether = same price
        utilities.daysOn(20), // lockEnds
        web3.utils.toWei("20000000"), // _maxSupply
        utilities.daysOn(18), // _escrowLimitPeriod
        { from: users[9].address }
        )
    })


    it('HSToken set STO_FLAGS', async () => {
      await newToken.set_STO_FLAGS(
          true, // _LIMITED_OWNERSHIP, 
          false, // _PERIOD_LOCKED,
          true, // _PERC_OWNERSHIP_TYPE,
          true, // _HYDRO_AMOUNT_TYPE,
          true, // WHITELIST_RESTRICTED
          true, // BLACKLIST_RESTRICTED
        { from: users[9].address }
        )
    })


    it('HSToken set STO_PARAMS', async () => {
      await newToken.set_STO_PARAMS(
          web3.utils.toWei("0.2"), // _percAllowedTokens: 1 ether = 100%, 0.2 ether = 20%
          web3.utils.toWei("1000"), // _hydroAllowed,
          utilities.daysToSeconds(12).toString(), // _lockPeriod,
          "1", // _minInvestors,
          "4", // _maxInvestors
          users[5].address, // hydroOracle
        { from: users[9].address }
        )
    })


    it('HSToken set Issuer Properties', async () => {
      await newToken.setIssuerProperties(
          "Company Name", // Company name
          "1234567890", // RegisteredNumber,
          "NYC, USA", // jurisdiction,
          users[9].address, // fundManager (can be 0x0 for Shares and Bonds),
          "0", // carriedInterestRate
        { from: users[9].address }
        )
    })


    it('HSToken activate Prelaunch', async () => {
      await newToken.stagePrelaunch({ from: users[9].address });
    })

    it('HSToken activate Presale', async () => {
      await newToken.stagePresale({ from: users[9].address });
    })

    it('HSToken activate Sale', async () => {
      await newToken.stageSale({ from: users[9].address });
    })


    it('HSToken adds EIN 2 to whitelist', async() => {
      await newToken.addWhitelist(["2"],
        { from: users[9].address })
    })

    it('HydroToken user 2 approves 1M HydroTokens for HSToken', async() => {
      await instances.HydroToken.approve(
        newToken.address,
        web3.utils.toWei("1000000"),
        { from: users[1].address })
    })

    it('HSTBuyerRegistry - get buyer data - kyc status: false', async () => {
      _buyerKycStatus = await instances.BuyerRegistry.getBuyerKycStatus(
        '2',
        {from: users[9].address}
      )
      console.log("      HSTBuyerRegistry kyc status", _buyerKycStatus)
    })

    it('HSToken Reverts buy for EIN user 3', async () => {
        await truffleAssert.reverts(
          newToken.buyTokens(
          "10",
          { from: users[2].address }),
          "Buyer must be approved for KYC"
        )
    })

    it('Set buyer kyc status true for user 1', async () => {
      await instances.BuyerRegistry.setBuyerKycStatus(
        '2', // buyer EIN
        newToken.address, // token address
        true, // kyc status
        {from: users[8].address} // kyc provider
      )
    })

    it('HSTBuyerRegistry - get buyer data - kyc status: true', async () => {
      _buyerKycStatus = await instances.BuyerRegistry.getBuyerKycStatus(
        '2',
        {from: users[9].address}
      )
      console.log("      HSTBuyerRegistry kyc status", _buyerKycStatus)
    })

    it('HSToken buyTokens from EIN user 2', async () => {
      await newToken.buyTokens(
          web3.utils.toWei("12"),
          { from: users[1].address })
    })


    it('HSToken buyTokens again from EIN user 2', async () => {
      await newToken.buyTokens(
          web3.utils.toWei("24"),
          { from: users[1].address })
    })

    it('HSToken activate Lock', async () => {
      await newToken.stageLock({ from: users[9].address });
    })

    it('HSToken activate Market', async () => {
      await newToken.stageMarket({ from: users[9].address });
    })

    it('Store periods', async() => {

      // var now = parseInt(new Date().getTime() / 1000) + 20
      // Get now from blockchain (to avoid errors from previous timetravels)
      var nowReceived = await newToken.getNow()
      var now = parseInt(nowReceived.toNumber())
      console.log("NOW: ", now)
      var periods = []
      for (i=1; i < 25; i++) {
        // Stablish 24 periods of payment, separated 200 seconds from eachother
        periods.push(now + i * 200)
      }

      await utilities.timeTravel(200)

      var tx = await newToken.addPaymentPeriodBoundaries(
          periods,
          { from: users[9].address })
      console.log("Gas:",tx.receipt.gasUsed)
    })


    it('Read periods', async() => {
      var getPeriods = await newToken.getPaymentPeriodBoundaries(
            { from: users[9].address })
      console.log("Periods:",getPeriods.map(period=>period.toNumber()))
      var now = await newToken.getNow()
      console.log("Now:", now.toNumber())

      currentPeriod = await newToken.getPeriod(
        { from: users[9].address });
      console.log("Current period:",currentPeriod.toNumber())
    })


    it('HSToken reverts transfer 1.2 HSTokens to Account 2', async () => {
      await truffleAssert.reverts(
        newToken.transfer(
          users[2].address,
          web3.utils.toWei("1.2"),
          { from: users[1].address })
      )
      //after(async()=>{
          console.log("Balance user 1:", web3.utils.fromWei(await newToken.balanceOf(users[1].address)))
          console.log("Balance user 3:", web3.utils.fromWei(await newToken.balanceOf(users[2].address)))
      //})
    })


    it('Set buyer kyc status true for user 2', async () => {
      await instances.BuyerRegistry.setBuyerKycStatus(
        '3', // buyer EIN
        newToken.address, // token address
        true, // kyc status
        {from: users[8].address} // kyc provider
      )
    })



    it('HSToken transfer 1.2 HSTokens to Account 2', async () => {

      console.log("Balance user 1:", web3.utils.fromWei(await newToken.balanceOf(users[1].address)))
      console.log("Balance user 3:", web3.utils.fromWei(await newToken.balanceOf(users[2].address)))

      var transfer = await newToken.transfer(
        users[2].address,
        web3.utils.toWei("1.2"),
        { from: users[1].address })

      //after(async()=>{
          console.log("Balance user 1:", web3.utils.fromWei(await newToken.balanceOf(users[1].address)))
          console.log("Balance user 3:", web3.utils.fromWei(await newToken.balanceOf(users[2].address)))
      //})

      console.log("Gas used by Transfer:", transfer.receipt.gasUsed)
    })




    it('Setting oracle address', async() => {
      await newToken.addHydroOracle(
        users[5].address,
        { from: users[9].address })
    })

    it('Oracle notifies profits of 5 Hydros for this period', async() => {
      await newToken.notifyPeriodProfits(
        web3.utils.toWei("5"),
        { from: users[5].address })
    })

    it('User claims payment 1', async() => {

      var payment = await newToken.claimPayment(
        { from: users[1].address })

      console.log("Period payed:", payment.receipt.logs[1].args.periodToPay.toNumber())
      console.log("Participation rate:", web3.utils.fromWei(payment.receipt.logs[1].args.investorParticipationRate))
      console.log("Period profits:", web3.utils.fromWei(payment.receipt.logs[1].args.periodProfits))
      console.log("Amount payed:", web3.utils.fromWei(payment.receipt.logs[1].args.paymentForInvestor))
      console.log("Amount from transfer log:", web3.utils.fromWei(payment.receipt.logs[0].args._amount))
      console.log("HydroToken Balance user 1 AFTER:", web3.utils.fromWei(await instances.HydroToken.balanceOf(users[1].address)))

    })


    it('Oracle notifies profits of 4 Hydros for this period', async() => {
      await utilities.timeTravel(300)

      await newToken.notifyPeriodProfits(
        web3.utils.toWei("4"),
        { from: users[5].address })
    })

    it('User claims payment 2', async() => {
      var payment = await newToken.claimPayment(
        { from: users[1].address })
      console.log("Period payed:", payment.receipt.logs[1].args.periodToPay.toNumber())
      console.log("Participation rate:", web3.utils.fromWei(payment.receipt.logs[1].args.investorParticipationRate))
      console.log("Period profits:", web3.utils.fromWei(payment.receipt.logs[1].args.periodProfits))
      console.log("Amount payed:", web3.utils.fromWei(payment.receipt.logs[1].args.paymentForInvestor))
      console.log("Amount from transfer log:", web3.utils.fromWei(payment.receipt.logs[0].args._amount))
      console.log("HydroToken Balance user 1 AFTER:", web3.utils.fromWei(await instances.HydroToken.balanceOf(users[1].address)))

    })

    it('Advancing periods', async () => {
      period = await newToken.getPeriod(
        { from: users[9].address });
      console.log("Current Period:", period.toNumber())

      await utilities.timeTravel(400)

      period = await newToken.getPeriod(
        { from: users[9].address });
      console.log("Current Period:", period.toNumber())

    })

    it('HSToken transfer 0.8 HSTokens to Account 2, to decrease his participationRate at period 4', async () => {

      await newToken.transfer(
        users[2].address,
        web3.utils.toWei("0.8"),
        { from: users[1].address })

      //after(async()=>{
          console.log("Balance user 1:", web3.utils.fromWei(await newToken.balanceOf(users[1].address)))
          console.log("Balance user 3:", web3.utils.fromWei(await newToken.balanceOf(users[2].address)))
      //})
    })

    it('Advancing new period', async () => {
      await utilities.timeTravel(200)

      period = await newToken.getPeriod(
        { from: users[9].address });
      console.log("Current Period:", period.toNumber())

    })

    it('Oracle notifies profits of 5 Hydros for this period', async() => {
      await newToken.notifyPeriodProfits(
        web3.utils.toWei("5"),
        { from: users[5].address })
    })


    it('User claims payment 1 but there is nothing, once', async() => {
      var payment = await newToken.claimPayment(
        { from: users[1].address })
      console.log("Period payed:", payment.logs[0].args.periodToPay.toNumber())
      console.log("Participation rate:", web3.utils.fromWei(payment.logs[0].args.investorParticipationRate))
      console.log("Period profits:", web3.utils.fromWei(payment.logs[0].args.periodProfits))
      console.log("Amount payed:", web3.utils.fromWei(payment.logs[0].args.paymentForInvestor))
    })


    it('User claims payment 1 but there is nothing twice', async() => {
      var payment = await newToken.claimPayment(
        { from: users[1].address })
      console.log("Period payed:", payment.logs[0].args.periodToPay.toNumber())
      console.log("Participation rate:", web3.utils.fromWei(payment.logs[0].args.investorParticipationRate))
      console.log("Period profits:", web3.utils.fromWei(payment.logs[0].args.periodProfits))
      console.log("Amount payed:", web3.utils.fromWei(payment.receipt.logs[0].args.paymentForInvestor))
    })

    it('User claims payment 1 and now it works', async() => {
      var payment = await newToken.claimPayment(
        { from: users[1].address })
      console.log("Period payed:", payment.receipt.logs[1].args.periodToPay.toNumber())
      console.log("Participation rate:", web3.utils.fromWei(payment.receipt.logs[1].args.investorParticipationRate))
      console.log("Period profits:", web3.utils.fromWei(payment.receipt.logs[1].args.periodProfits))
      console.log("Amount payed:", web3.utils.fromWei(payment.receipt.logs[1].args.paymentForInvestor))
      console.log("Amount from transfer log:", web3.utils.fromWei(payment.receipt.logs[0].args._amount))
      console.log("HydroToken Balance user 1 AFTER:", web3.utils.fromWei(await instances.HydroToken.balanceOf(users[1].address)))

    })


  })
})
