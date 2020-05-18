<h1>HST - Hydro Security Tokens Framework</h1>

<h2>Security Tokens Generator and Manager</h2>

<h3>Description</h3>

This is a set of Ethereum Smart Contracts which work on top of Hydro Snowflake. They allow a validated Snowflake address to create standardized Security Tokens that can be issued, bought and sold, validated, transferred, paid as dividends, and destroyed.



<h3>Architecture draft</h3>

<p>
  <img src="https://github.com/juanlive/hst/blob/master/images/HST%20Securities%20Architecture.png" width="500">
</p>

<h3>To run tests</h3>

1. Run the following:
npm install

2. Build dependencies with:
npm run build

3. Spin up a development blockchain using:
npm run chain

4. Then in another console window, run this:
npm run test

You can find an example test run in the file test.txt


<h3>Features (some are yet work-in-progress)</h3>

    Create Security Token - unique IDs are attributed to each token, called a Hydro Security Token or HST

    Define HST Rules - create a dictionary of rules that can be applied to the HST
    
    KYC Approval - n-chain KYC approval from off-chain KYC provider(s) of token issuer and buyers/sellers for defined ruleset

    AML Approval - on-chain AML approval from off-chain AML provider(s) for token issuer and buyers/sellers for defined ruleset

    Limit Owners - limit ownership percentage, or HYDRO amount for any HST

    Legal Approval - on-chain legal approval from off-chain legal providers to prove rightful creation, ownership, and structure of security token

    Legal Contracts - tie the HST to legal contracts and terms/conditions written off-chain via Hydro Ice.

    Restricted Transfers - override normal ERC-20 transfer methods to block transfers of HST between wallets if not on a KYC/AML whitelist

    Lockup Periods - set rules to lock token transfers and buy/sells for a period of X time

    Admin Function - an admin or issuer can modify rules, whitelist/blacklist, lock, freeze, or stop token transfers at any time

    Participant Functions - send and receive a token tied to ERC-1484 wallet ID, lockup, freeze, blacklist any ID

    HST Escrow - keep HYDRO tokens in escrow contract within ERC-1484 of issuer, until offering is closed, release back to ERC-1484 wallet ID of subscriber from escrow if conditions in legal contract aren’t met

    Subscription - use the Snowflake Subscription task to create a framework for payments and recurring subscriptions to a securitization

    Authenticate - use Hydro Raindrop to authenticate issuance, purchase/sale, transfer

    Carried Interest - calculate carried interest based on the Interest Smart Contract utility function (link when posted)

    Interest Payout - payout carried interest/management fee to token issuer on a set schedule to defined wallet IDs on the whitelist

    Dividend Payout - payout dividend from admin pro-rata to Snowflake wallet holders in HYDRO
    


<h3>HSTOken - General Description and Usage</h3>

<h4>Tutorial: How to issue a token</h4>


This tutorial shows you how to issue a new token using the Hydro Securities Token framework. Token creation and setup will be performed by calling functions in the HSToken smart contract. Instructions follow.


<h5>Token creation</h5>

Call the HSToken Constructor

The following are required values for the creation of a new token, and must be provided by the owner/issuer of the token, possibly through a dApp, or as parameters if invoking the smart contract directly.

        uint256 id: Token iD
        uint8 stoType: STO type: (0: Shares, 1: Units, 2: Bonds)
        bytes32 name: Name of the token
        string memory description: Description
        bytes32 symbol: Symbol
        uint8 decimals: Decimals

The following values (along with the first id) will be provided by the system itself (in the future, by means of HSToken Factory or a dApp) meanwhile (for testing purposes) they must be manually provided:

        address hydroToken: Address of HydroToken (*)
        address identityRegistry: Address of Identity Registry (*)
        address buyerRegistry: Address of Buyer Registry (*)
        address payable owner: Owner address. EIN of owner/issuer will be obtained from this address and will be used to authenticate internally with the einOwner variable.

 (*) these addresses are expected for, in the constructor, to allow for testing to be performed in different blockchains (Rinkeby, Kovan, MainNet, and so)

Once created, a new token initializes itself as being in stage = SETUP

During this stage the token:
is not active
its name is protected

The owner/issuer has 15 days to fill the main parameters to setup the token. This was made to facilitate the life of the token owner/issuer.

<h5>Token setup</h5>

To setup the token, 4 different functions shall be called, each one with their corresponding parameters:

    function set_MAIN_PARAMS(
        uint256 _hydroPrice, Price in HydroTokens
        uint256 _lockEnds, Date of unlocking of token
        uint256 _maxSupply, Max supply of tokens
        uint256 _escrowLimitPeriod, amount of time in seconds for escrow
    )

    function set_STO_FLAGS(
        bool _LIMITED_OWNERSHIP, Will the ownership be limited?
        bool _PERIOD_LOCKED, Will the token will be limited for a period?
        bool _PERC_OWNERSHIP_TYPE, Will ownership be limited by percentage?
        bool _HYDRO_AMOUNT_TYPE, Will be restricted by amount of hydrotokens?
        bool _WHITELIST_RESTRICTED, Whitelist restriction
        bool _BLACKLIST_RESTRICTED, Blacklist restriction
    )

    function set_STO_PARAMS(
        uint256 _percAllowedTokens, if _PERC_OWNERSHIP_TYPE is true, this will be the percentage (*)
        uint256 _hydroAllowed, if _HYDRO_AMOUNT_TYPE is true, this will be the limit
        uint256 _lockPeriod, if _PERIOD_LOCKED is true, this will be the period
        uint256 _minInvestors, minimum number of investors allowed
        uint256 _maxInvestors, maximum number of investors allowed
        address _hydroOracle, address of oracle to update hydro price of token (if any)
    )

    function setIssuerProperties(
        string issuerName, company Name
        string registeredNumber, registered Number
        string jurisdiction, jurisdiction
        address payable fundManager, fund manager address
        uint256 carriedInterestRate, carried interest rate
    )

 (*) For convenience in internal calculations, percentages are expressed in weiss. 1 ether represents 100%, 0.5 ethers 50% and so on.

<h5>Token pre-launch</h5>

After calling these three functions, the owner/issuer can call:

function stagePrelaunch() 

If all previously shown settings were correctly made, the token will be activated and it will be in stage = PRELAUNCH

During the pre-launch stage, the owner/issuer can add or remove bulk EIN identities from whitelist or blacklist by calling the following functions:

addWhitelist(uint[])
addBlacklist(uint[])

Setting KYC, AML and Legal providers:

1. Token owner must call ServiceRegistry to appoint a provider using the following function:

addService(
    address tokenAddress, ethereum address of the token
    uint serviceProviderEIN, EIN of service provider
    bytes32 categorySymbol, (“KYC”, “AML”, “MLA”, “CFT”)
)

2. Token owner can select KYC service for each user calling to BuyerRegistry:

addKycServiceToBuyer(
        uint buyerEI, EIN of the buyer
        address tokenFor, address of the token
        uint serviceProviderEIN, EIN of KYC provider
)

Same with all other services:

addAmlServiceToBuyer
addCftServiceToBuyer

At any time, the owner/issuer can add or remove bulk EIN identities from whitelist or blacklist by calling the following functions:

addWhitelist(uint[])
addBlacklist(uint[])

Before changing to presale state, token must be approved by the “Main Legal Advisor”.

1. Appoint the “Main legal advisor” by calling ServiceRegistry:

addService(
address, token address
uint, service provider EIN
bytes32, “MLA”
)

2. Then the “Main Legal Advisor” should grant legal approval for the token calling to TokenRegistry:

grantLegalApproval(
address, token address
)

This call should be done by an address pertaining to the EIN registered as the MLA service.

<h5>Token pre-sale</h5>

Owner/issuer can activate the presale stage of the token by calling the function

stagePresale()

Token should be approved by the “Main Legal Advisor” in order to advance to this stage.
Once activated, buyers in the whitelist can start buying tokens. 

To buy tokens during the active stages:

buyTokens(uint _amount)

_amount specifies the amount of HydroTokens that will be paid, which should be approved in the HydroToken for the HSToken to use.

Buyer should be approved by KYC as a minimum, and according to token parameters, by AML and/or CFT service providers.

There can be restrictions of amount per investor, total amount of tokens, number of investors, or new rules that can be added in the future.

The token will call the function checkRules in BuyerRegistry to check if the buyer is authorized to buy.

<h5>Token sale</h5>

Owner/issuer can advance to the sale stage of the token by calling the function

stageSale()

This stage have characteristics similar to the previous one, with the exception that whitelists and blacklists are not checked. Other providers and token rules continue having effect, as token will continue calling checkRules in BuyerRegistry.

<h5>Token lock</h5>

Owner/issuer can activate the lock by calling the function

stageLock()

The minimum number of investors should be reached.

<h5>Market stage</h5>

Owner/issuer can activate the market stage by calling the function

stageMarket()

ERC-20 functions will be activated.

<h5>Token oraclizing</h5>

An Oracle can be assigned to the token, and it should call the following function to update the price of the token in Hydro tokens:

updateHydroPrice(uint)

Oracles can be assigned, replaced or revoked (by assigning a passive address) by the owner/issuer of the token, at any time, calling the function:

addHydroOracle(address)

<h5>Setting payments</h5>

Token owner must set periods for payment:

addPaymentPeriodBoundaries(
    uint[] periods
)

Each payment date is specified in timestamp in seconds.

<h5>Notifying profits</h5>

Oracle must notify each period profit calling to this function:

notifyPeriodProfits(
    uint profits
)

Value will be assigned to the last period without notification.

<h5>Claiming payments</h5>

Buyer must call this function:

claimPayment()

Each invocation will pay the last period pending.

<h5>Other administrative functions</h5>

setLockUpPeriod(uint _lockEnds)

Locks the token for a predetermined period. Date of unlock expressed as unix timestamp.

lock() / unLock()

Lock/unlocks the token.

freeze(uint[]) / unfreeze(uint[])

Freezes/unfreezes bulk or individual EIN identities for using the token.

releaseHydroTokens()

Release HydroTokens held in escrow to the owner/issuer.

<h5>Public Getters</h5>

getTokenEINOwner()

isTokenLocked()

isTokenAlive()

tokenInSetUpStage()

getPaymentPeriodBoundaries()

<h3>Granting a user permission to buy a Token - Javascript Example</h3>

We use a  group of pre-loaded contracts which we stored in the “instances” object array.
Also note that most steps are done by user number 1 (the token owner) but changing the user KYC status must be done by user number 2 (the service provider).
To allow a buyer to buy a Hydro Security Token, you need to follow this 6-steps recipe.

1. Appoint the Token to the Token Registry

<pre><code>
await instances.TokenRegistry.appointToken(
        tokenDummyAddress,
        web3.utils.fromAscii('TEST'),
        web3.utils.fromAscii('TestToken'),
        'just-a-test',
        10,
        {from: users[1].address}
)
</code></pre>

2. Assign Token buyer values in the Buyer Registry

<pre><code>
await instances.BuyerRegistry.assignTokenValues(
        tokenDummyAddress,
        '21', // minimum age
        '50000', // minimum net worth
        '36000', // minimum salary
        true, // accredited investor status required
        {from: user[1].address}
  )
</code></pre>

3. Add the Buyer to the Buyer Registry

<pre><code>
await instances.BuyerRegistry.addBuyer(
        '21', // EIN
        'Test first name 1',
        'Test last name 1',
        web3.utils.fromAscii('GMB'),
        '1984', // year of birth
        '12', // month of birth
        '12', // day of birth
        '100000', // net worth
        '50000', // salary
        {from: users[1].address}
  )
</code></pre>

4. Add a KYC Service to the Service Registry

<pre><code>
await instances.ServiceRegistry.addService(
        newToken.address,
        '3',
        web3.utils.fromAscii("KYC"),
        {from: users[1].address}
    )
</code></pre>

5. Assign a KYC Service to the Buyer in the Buyer Registry

<pre><code>
await instances.BuyerRegistry.addKycServiceToBuyer(
        '1',
        newToken.address,
        '3',
        {from: users[1].address}
  )
</code></pre>

6. Set KYC Status for the Buyer in the Buyer Registry

<pre><code>
await instances.BuyerRegistry.setBuyerKycStatus(
            '21',
        true,
            {from: users[2].address}
      )
</code></pre>
