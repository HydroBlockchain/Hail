pragma solidity ^0.5.0;

import './DateTime.sol';
import './HSTokenRegistry.sol';
import './HSTServiceRegistry.sol';
import './SnowflakeOwnable.sol';
import '../interfaces/IdentityRegistryInterfaceShort.sol';


/**
 * @title HSTBuyerRegistry
 *
 * @notice Rules enforcement and registry of buyers
 *
 * @dev  This contract performs the following functions:
 *
 * 1. Default rules enforcer for Hydro security tokens
 *
 * 2. A buyer registry to hold EINs of buyers for any security token.
 * The Service Registry contract has an array of EINs, holds and provides information for buyers of any token, this simplifies the management of an ecosystems of buyers.
 *
 * @author Fatima Castiglione Maldonado <castiglionemaldonado@gmail.com>
 */

contract HSTBuyerRegistry is SnowflakeOwnable {


    // token rules data

    struct rulesData {
        uint    minimumAge;
        uint64  minimumNetWorth;
        uint32  minimumSalary;
        bool    accreditedInvestorStatusRequired;
        bool    amlWhitelistingRequired;
        bool    cftWhitelistingRequired;
    }

    // token address => data to enforce rules
    mapping(address => rulesData) public tokenData;

    // token address => ISO country code => country is banned
    mapping(address => mapping(bytes32 => bool)) public bannedCountries;


    // buyer rules data

    struct buyerData {
        string  firstName;
        string  lastName;
        bytes32 isoCountryCode;
        uint    birthTimestamp;
        uint64  netWorth;
        uint32  salary;
        bool    accreditedInvestorStatus;
        bool    kycWhitelisted;
        bool    amlWhitelisted;
        bool    cftWhitelisted;
    }

    // EIN of each provider for buyers
    struct buyerServicesDetail {
        uint  kycProvider;
        uint  amlProvider;
        uint  cftProvider;
    }

    // buyer EIN => buyer data
    mapping(uint => buyerData) public buyerRegistryDetail;

    // buyer EIN => token address => service details for buyer
    mapping(uint => mapping(address => buyerServicesDetail)) public serviceDetailForBuyers;


    // external

    DateTime dateTime;
    HSTokenRegistry tokenRegistry;
    HSTServiceRegistry serviceRegistry;
    IdentityRegistryInterface identityRegistry;


    // rules events

    /**
    * @notice Triggered when rules data is added for a token
    */
    event TokenValuesAssigned(address _tokenAddress);

    /**
    * @notice Triggered when a country is banned for a token
    */
    event AddCountryBan(address _tokenAddress, bytes32 _isoCountryCode);

    /**
    * @notice Triggered when a country ban is lifted for a token
    */
    event LiftCountryBan(address _tokenAddress, bytes32 _isoCountryCode);

    // buyer events

    /**
    * @notice Triggered when buyer is added
    */
    event AddBuyer(uint _buyerEIN, string _firstName, string _lastName);

    /**
    * @notice Triggered when KYC service is added
    */
    event AddKycServiceToBuyer(uint _buyerEIN, address _tokenAddress, uint _providerEIN);

    /**
    * @notice Triggered when AML service is added
    */
    event AddAmlServiceToBuyer(uint _buyerEIN, address _tokenAddress, uint _providerEIN);

    /**
    * @notice Triggered when CFT service is added
    */
    event AddCftServiceToBuyer(uint _buyerEIN, address _tokenAddress, uint _providerEIN);

    /**
    * @notice Triggered when KYC service is replaced
    */
    event ReplaceKycServiceForBuyer(uint _buyerEIN, address _tokenAddress, uint _providerEIN);

    /**
    * @notice Triggered when AML service is replaced
    */
    event ReplaceAmlServiceForBuyer(uint _buyerEIN, address _tokenAddress, uint _providerEIN);

    /**
    * @notice Triggered when CFT service is replaced
    */
    event ReplaceCftServiceForBuyer(uint _buyerEIN, address _tokenAddress, uint _providerEIN);


    /**
    * @notice Constructor
    *
    * @param _dateTimeAddress address for the date time contract
    */
    constructor(address _dateTimeAddress) public {
        dateTime = DateTime(_dateTimeAddress);
    }


    /**
    * @dev Modifiers are paired with functions to optimize bytecode size at deployment time
    */

    /**
    * @dev Validate that a contract exists in an address received as such
    * Credit: https://github.com/Dexaran/ERC223-token-standard/blob/Recommended/ERC223_Token.sol#L107-L114
    * @param _addr The address of a smart contract
    */
    modifier isContract(address _addr) {
        _isContract(_addr);
        _;
    }
    function _isContract(address _addr) private view {
        uint length;
        assembly { length := extcodesize(_addr) }
        require(length > 0, "Address cannot be blank");
    }

   /**
    * @dev Validate that a token exists in token registry
    */
    modifier isRegisteredToken(address _tokenAddress) {
        _isRegisteredToken(_tokenAddress);
        _;
    }
    function _isRegisteredToken(address _tokenAddress) private view {
        require(tokenRegistry.isRegisteredToken(_tokenAddress) == true, "Token must be registered in Token Registry");
    }

   /**
    * @dev Validate that an EIN exists as provider for a token
    */
    modifier isRegisteredProvider(address _tokenAddress, uint _providerEIN) {
        _isRegisteredProvider(_tokenAddress, _providerEIN);
        _;
    }
    function _isRegisteredProvider(address _tokenAddress, uint _providerEIN) private view {
        require(serviceRegistry.isProvider(_tokenAddress, _providerEIN) == true, "Provider must be registered in Service Registry");
    }

    /**
    * @notice Throws if called by any account other than the owner
    * @dev This works on EINs, not on addresses
    */
    modifier onlyTokenOwner(address _tokenAddress) {
        _onlyTokenOwner(_tokenAddress);
        _;
    }
    function _onlyTokenOwner(address _tokenAddress) private view {
        require(isTokenOwner(_tokenAddress), "Caller must be the token EIN owner");
    }
    /**
    * @return true if `msg.sender` is the owner of the contract
    */
    function isTokenOwner(address _tokenAddress) public view returns(bool) {
        // find out owner EIN
        uint _tokenEINOwner = tokenRegistry.getSecuritiesTokenOwnerEIN(_tokenAddress);
        // find out caller EIN
        uint _senderEIN = identityRegistry.getEIN(msg.sender);
        // compare them
        return (_senderEIN == _tokenEINOwner);
    }

    /**
    * @notice Throws if called by any account who is not a registered token owner
    * @dev This works on EINs, not on addresses
    */
    modifier onlyRegisteredTokenOwner() {
        _onlyRegisteredTokenOwner();
        _;
    }
    function _onlyRegisteredTokenOwner() private view {
        require(isRegisteredTokenOwner(), "Caller address must be a registered token owner");
    }
    /**
    * @return true if `msg.sender` is the owner of the contract
    */
    function isRegisteredTokenOwner() public view returns(bool) {
        // find out caller EIN
        uint _senderEIN = identityRegistry.getEIN(msg.sender);
        // find out if it is a registered owner EIN
        return tokenRegistry.isRegisteredOwner(_senderEIN);
    }

    /**
    * @notice Throws if called by any account other than the KYC provider for this buyer
    * @dev This works on EINs, not on addresses
    */
    modifier onlyRegisteredKycProvider(uint _buyerEIN, address _tokenAddress) {
        _onlyRegisteredKycProvider(_buyerEIN, _tokenAddress);
        _;
    }
    function _onlyRegisteredKycProvider(uint _buyerEIN, address _tokenAddress) private view {
        require(isRegisteredKycProvider(_buyerEIN, _tokenAddress),
        "Caller address must be a registered KYC provider for this buyer");
    }
    /**
    * @return true if `msg.sender` is a registered KYC provider for the buyer
    */
    function isRegisteredKycProvider(uint _buyerEIN, address _tokenAddress)
    public view returns(bool) {
        // find out caller EIN
        uint _senderEIN = identityRegistry.getEIN(msg.sender);
        // find out if it is a registered owner EIN
        require(serviceDetailForBuyers[_buyerEIN][_tokenAddress].kycProvider == _senderEIN,
        "Must be the registered KYC provider for this buyer");
        return true;
    }

    /**
    * @notice Throws if called by any account other than the AML provider for this buyer
    * @dev This works on EINs, not on addresses
    */
    modifier onlyRegisteredAmlProvider(uint _buyerEIN, address _tokenAddress) {
        _onlyRegisteredAmlProvider(_buyerEIN, _tokenAddress);
        _;
    }
    function _onlyRegisteredAmlProvider(uint _buyerEIN, address _tokenAddress) private view {
        require(isRegisteredAmlProvider(_buyerEIN, _tokenAddress),
        "Caller address must be a registered AML provider for this buyer");
    }
    /**
    * @return true if `msg.sender` is a registered KYC provider for the buyer
    */
    function isRegisteredAmlProvider(uint _buyerEIN, address _tokenAddress)
    public view returns(bool) {
        // find out caller EIN
        uint _senderEIN = identityRegistry.getEIN(msg.sender);
        // find out if it is a registered owner EIN
        require(serviceDetailForBuyers[_buyerEIN][_tokenAddress].amlProvider == _senderEIN,
        "Must be the registered AML provider for this buyer");
        return true;
    }

    /**
    * @notice Throws if called by any account other than the CFT provider for this buyer
    * @dev This works on EINs, not on addresses
    */
    modifier onlyRegisteredCftProvider(uint _buyerEIN, address _tokenAddress) {
        _onlyRegisteredCftProvider(_buyerEIN, _tokenAddress);
        _;
    }
    function _onlyRegisteredCftProvider(uint _buyerEIN, address _tokenAddress) private view {
        require(isRegisteredCftProvider(_buyerEIN, _tokenAddress),
        "Caller address must be a registered CFT provider for this buyer");
    }
    /**
    * @return true if `msg.sender` is a registered CFT provider for the buyer
    */
    function isRegisteredCftProvider(uint _buyerEIN, address _tokenAddress)
    public view returns(bool) {
        // find out caller EIN
        uint _senderEIN = identityRegistry.getEIN(msg.sender);
        // find out if it is a registered owner EIN
        require(serviceDetailForBuyers[_buyerEIN][_tokenAddress].cftProvider == _senderEIN,
        "Must be the registered CFT provider for this buyer");
        return true;
    }


    // functions for contract configuration

    /**
    * @notice configure this contract
    * @dev this contract need to communicate with token and service registries
    *
    * @param _identityRegistryAddress The address for the identity registry
    * @param _tokenRegistryAddress The address for the token registry
    * @param _serviceRegistryAddress The address for the service registry
    *
    */
    function setAddresses(
        address _identityRegistryAddress,
        address _tokenRegistryAddress,
        address _serviceRegistryAddress)
        public
        isContract(_identityRegistryAddress)
        isContract(_tokenRegistryAddress)
        isContract(_serviceRegistryAddress)
    {
        //setIdentityRegistryAddress(_identityRegistryAddress);
        identityRegistry = IdentityRegistryInterface(_identityRegistryAddress);
        tokenRegistry = HSTokenRegistry(_tokenRegistryAddress);
        serviceRegistry = HSTServiceRegistry(_serviceRegistryAddress);
    }


    // functions for token rules update

    /**
    * @notice Assign rule values for each token
    *
    * @dev This function is only callable by the token owner
    *
    * @param _tokenAddress Address for the Token
    * @param _minimumAge Required minimum age to buy this Token
    * @param _minimumNetWorth Required minimum net work to buy this Token
    * @param _minimumSalary Required minimum salary to buy this Token
    * @param _accreditedInvestorStatusRequired Determines if buyer must be an accredited investor to buy this Token
    */
    function assignTokenValues(
        address _tokenAddress,
        uint _minimumAge,
        uint64 _minimumNetWorth,
        uint32 _minimumSalary,
        bool _accreditedInvestorStatusRequired,
        bool _amlWhitelistingRequired,
        bool _cftWhitelistingRequired)
    public
    onlyTokenOwner(_tokenAddress)
    {
        tokenData[_tokenAddress].minimumAge = _minimumAge;
        tokenData[_tokenAddress].minimumNetWorth = _minimumNetWorth;
        tokenData[_tokenAddress].minimumSalary = _minimumSalary;
        tokenData[_tokenAddress].accreditedInvestorStatusRequired = _accreditedInvestorStatusRequired;
        tokenData[_tokenAddress].amlWhitelistingRequired = _amlWhitelistingRequired;
        tokenData[_tokenAddress].cftWhitelistingRequired = _cftWhitelistingRequired;
        emit TokenValuesAssigned(_tokenAddress);
    }

    /**
    * @notice get token rules data
    *
    * @param _tokenAddress Address for the Token
    * @return minimum age required to buy this token
    */
    function getTokenMinimumAge(address _tokenAddress) public view returns (uint) {
        return tokenData[_tokenAddress].minimumAge;
    }

    /**
    * @notice get token rules data
    *
    * @param _tokenAddress Address for the Token
    * @return minimum net worth required to buy this token
    */
    function getTokenMinimumNetWorth(address _tokenAddress) public view returns (uint64) {
        return tokenData[_tokenAddress].minimumNetWorth;
    }

    /**
    * @notice get token rules data
    *
    * @param _tokenAddress Address for the Token
    * @return minimum salary required to buy this token
    */
    function getTokenMinimumSalary(address _tokenAddress) public view returns (uint32) {
        return tokenData[_tokenAddress].minimumSalary;
    }

    /**
    * @notice get token rules data
    *
    * @param _tokenAddress Address for the Token
    * @return is accredited investor status required to buy this token?
    */
    function getTokenInvestorStatusRequired(address _tokenAddress) public view returns (bool) {
        return tokenData[_tokenAddress].accreditedInvestorStatusRequired;
    }

  /**
  * @notice Get legal approval status for a security token
  *
  * @param  _tokenAddress The address of the Token
  * @return true if the token has legal approval
  */
  function getTokenLegalStatus(address _tokenAddress) public view returns(bool) {
    return tokenRegistry.checkLegalApproval(_tokenAddress);
  }


    // country ban functions

    /**
    * @notice ban a country for participation
    *
    * @dev This method is only callable by the contract's owner
    *
    * @param _tokenAddress Address for the Token
    * @param _isoCountryCode Country to be banned for this Token
    */
    function addCountryBan(
        address _tokenAddress,
        bytes32 _isoCountryCode)
    public
        onlyTokenOwner(_tokenAddress)
    {
        bannedCountries[_tokenAddress][_isoCountryCode] = true;
        emit AddCountryBan(_tokenAddress, _isoCountryCode);
    }

    /**
    * @notice get token rules data
    *
    * @param _tokenAddress Address for the Token
    * @param _isoCountryCode Country to find out status
    *
    * @return country status
    */
    function getCountryBan(
        address _tokenAddress,
        bytes32 _isoCountryCode)
        public view returns (bool) {
        return bannedCountries[_tokenAddress][_isoCountryCode];
    }

    /**
    * @notice lift a country ban for participation
    *
    * @dev This method is only callable by the contract's owner
    *
    * @param _tokenAddress Address for the Token
    * @param _isoCountryCode Country to be unbanned for this Token
    */
    function liftCountryBan(
        address _tokenAddress,
        bytes32 _isoCountryCode)
    public
        onlyTokenOwner(_tokenAddress)
    {
        bannedCountries[_tokenAddress][_isoCountryCode] = false;
        emit LiftCountryBan(_tokenAddress, _isoCountryCode);
    }


    // functions for buyer's registry - user data

    /**
    * @notice Add a new buyer
    * @dev    This method is only callable by the contract's owner
    *
    * @param _buyerEIN EIN for the buyer
    * @param _firstName First name of the buyer
    * @param _lastName Last name of the buyer
    * @param _isoCountryCode ISO country code for the buyer
    * @param _yearOfBirth Year of birth of the buyer
    * @param _monthOfBirth Month of birth of the buyer
    * @param _dayOfBirth Day of birth of the buyer
    * @param _netWorth Net worth declared by the buyer
    * @param _salary Salary declared by the buyer
    */
    function addBuyer(
        uint _buyerEIN,
        string memory _firstName,
        string memory _lastName,
        bytes32 _isoCountryCode,
        uint16 _yearOfBirth,
        uint8 _monthOfBirth,
        uint8 _dayOfBirth,
        uint64 _netWorth,
        uint32 _salary)
    public onlyRegisteredTokenOwner() {
        buyerData memory _bd;
        _bd.firstName = _firstName;
        _bd.lastName = _lastName;
        _bd.isoCountryCode = _isoCountryCode;
        _bd.birthTimestamp = dateTime.toTimestamp(_yearOfBirth, _monthOfBirth, _dayOfBirth);
        _bd.netWorth = _netWorth;
        _bd.salary = _salary;
        buyerRegistryDetail[_buyerEIN] = _bd;
        emit AddBuyer(_buyerEIN, _firstName, _lastName);
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _firstName First name of the buyer
    */
    function getBuyerFirstName(uint _buyerEIN) public view returns (string memory) {
        return buyerRegistryDetail[_buyerEIN].firstName;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _lastName Last name of the buyer
    */
    function getBuyerLastName(uint _buyerEIN) public view returns (string memory) {
        return buyerRegistryDetail[_buyerEIN].lastName;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _isoCountryCode ISO country code for the buyer
    */
    function getBuyerIsoCountryCode(uint _buyerEIN) public view returns (bytes32) {
        return buyerRegistryDetail[_buyerEIN].isoCountryCode;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return birthTimestamp Timestamp for birthday of the buyer
    */
    function getBuyerBirthTimestamp(uint _buyerEIN) public view returns (uint) {
        return buyerRegistryDetail[_buyerEIN].birthTimestamp;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _netWorth Net worth declared by the buyer
    */
    function getBuyerNetWorth(uint _buyerEIN) public view returns (uint64) {
        return buyerRegistryDetail[_buyerEIN].netWorth;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _salary Salary declared by the buyer
    */
    function getBuyerSalary(uint _buyerEIN) public view returns (uint32) {
        return buyerRegistryDetail[_buyerEIN].salary;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _accreditedInvestorStatus Investor status for the buyer
    */
    function getBuyerInvestorStatus(uint _buyerEIN) public view returns (bool) {
        return buyerRegistryDetail[_buyerEIN].accreditedInvestorStatus;
    }

    /**
    * @notice set buyer data
    *
    * @param _buyerKycStatus KYC status for the buyer
    */
    function setBuyerKycStatus(uint _buyerEIN, address _tokenAddress, bool _buyerKycStatus)
    public onlyRegisteredKycProvider(_buyerEIN, _tokenAddress) {
        buyerRegistryDetail[_buyerEIN].kycWhitelisted = _buyerKycStatus;
    }

    /**
    * @notice set buyer data
    *
    * @param _buyerAmlStatus AML status for the buyer
    */
    function setBuyerAmlStatus(uint _buyerEIN, address _tokenAddress, bool _buyerAmlStatus)
    public onlyRegisteredAmlProvider(_buyerEIN, _tokenAddress) {
        buyerRegistryDetail[_buyerEIN].amlWhitelisted = _buyerAmlStatus;
    }

    /**
    * @notice set buyer data
    *
    * @param _buyerCftStatus CFT status for the buyer
    */
    function setBuyerCftStatus(uint _buyerEIN, address _tokenAddress, bool _buyerCftStatus)
    public onlyRegisteredCftProvider(_buyerEIN, _tokenAddress) {
        buyerRegistryDetail[_buyerEIN].cftWhitelisted = _buyerCftStatus;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _kycWhitelisted KYC status for the buyer
    */
    function getBuyerKycStatus(uint _buyerEIN) public view returns (bool) {
        return buyerRegistryDetail[_buyerEIN].kycWhitelisted;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _amlWhitelisted KYC status for the buyer
    */
    function getBuyerAmlStatus(uint _buyerEIN) public view returns (bool) {
        return buyerRegistryDetail[_buyerEIN].amlWhitelisted;
    }

    /**
    * @notice get buyer data
    *
    * @param _buyerEIN EIN for the buyer
    * @return _cftWhitelisted KYC status for the buyer
    */
    function getBuyerCftStatus(uint _buyerEIN) public view returns (bool) {
        return buyerRegistryDetail[_buyerEIN].cftWhitelisted;
    }


    // functions for buyer's registry - manage services for a buyer

    /**
    * @notice Add a new KYC service for a buyer
    *
    * @param _buyerEIN EIN of the buyer
    * @param _tokenFor Token that uses this service
    * @param _serviceProviderEIN The new KYC service provider for this buyer
    */
    function addKycServiceToBuyer(
        uint _buyerEIN,
        address _tokenFor,
        uint _serviceProviderEIN)
    public
        isRegisteredToken(_tokenFor)
        isRegisteredProvider(_tokenFor, _serviceProviderEIN)
        onlyTokenOwner(_tokenFor)
    {
        // control buyer
        require(_buyerEIN != 0, "Buyer EIN cannot be blank");
        // control that caller is owner
        // uint _callerEIN = identityRegistry.getEIN(msg.sender);
        // require(_callerEIN == tokenRegistry.getSecuritiesTokenOwnerEIN(_tokenFor),
        //     "Caller must be the token owner");
        // control that service provider is registered
        // require(serviceRegistry.getService(_tokenFor, _serviceProviderEIN) == "KYC",
        //     "Service provider must be a registered provider for KYC in Service Registry");
        serviceDetailForBuyers[_buyerEIN][_tokenFor].kycProvider = _serviceProviderEIN;
        emit AddKycServiceToBuyer(_buyerEIN, _tokenFor, _serviceProviderEIN);
    }

    /**
    * @notice Get KYC service for a buyer
    *
    * @param _buyerEIN EIN of the buyer
    * @param _tokenFor Token that uses this service
    *
    * @return The KYC service provider for buyer and token
    */
    function getKycServiceForBuyer(
        uint _buyerEIN,
        address _tokenFor)
    public view
    returns (uint)
    {
        return serviceDetailForBuyers[_buyerEIN][_tokenFor].kycProvider;
    }

    /**
    * @notice Add a new AML service for a buyer
    *
    * @param _buyerEIN EIN of the buyer
    * @param _tokenFor Token that uses this service
    */
    function addAmlServiceToBuyer(
        uint _buyerEIN,
        address _tokenFor,
        uint _serviceProviderEIN)
    public
        isRegisteredToken(_tokenFor)
        isRegisteredProvider(_tokenFor, _serviceProviderEIN)
        onlyTokenOwner(_tokenFor)
    {
        // control buyer
        require(_buyerEIN != 0, "Buyer EIN cannot be blank");
        // control that caller is owner
        // uint _callerEIN = identityRegistry.getEIN(msg.sender);
        // require(_callerEIN == tokenRegistry.getSecuritiesTokenOwnerEIN(_tokenFor),
        //     "Caller must be the token owner");
        // control that service provider is registered
        // require(serviceRegistry.getService(_tokenFor, _serviceProviderEIN) == "AML",
        //     "Service provider must be a registered provider for AML in Service Registry");
        serviceDetailForBuyers[_buyerEIN][_tokenFor].amlProvider = _serviceProviderEIN;
        emit AddAmlServiceToBuyer(_buyerEIN, _tokenFor, _serviceProviderEIN);
    }

    /**
    * @notice Add a new CFT service for a buyer
    *
    * @param _buyerEIN EIN of the buyer
    * @param _tokenFor Token that uses this service
    */
    function addCftServiceToBuyer(
        uint _buyerEIN,
        address _tokenFor,
        uint _serviceProviderEIN)
    public
        isRegisteredToken(_tokenFor)
        isRegisteredProvider(_tokenFor, _serviceProviderEIN)
        onlyTokenOwner(_tokenFor)
    {
        // control buyer
        require(_buyerEIN != 0, "Buyer EIN cannot be blank");
        // control that caller is owner
        // uint _callerEIN = identityRegistry.getEIN(msg.sender);
        // require(_callerEIN == tokenRegistry.getSecuritiesTokenOwnerEIN(_tokenFor),
        //     "Caller must be the token owner");
        // control that service provider is registered
        // require(serviceRegistry.getService(_tokenFor, _serviceProviderEIN) == "CFT",
        //     "Service provider must be a registered provider for CFT in Service Registry");
        serviceDetailForBuyers[_buyerEIN][_tokenFor].cftProvider = _serviceProviderEIN;
        emit AddCftServiceToBuyer(_buyerEIN, _tokenFor, _serviceProviderEIN);
    }


    // functions to enforce investor rules

    /**
    * @notice Enforce rules for the investor
    *
    * @dev This method is only callable by a contract
    *
    * @param _buyerEIN EIN of the buyer
    */
    function checkRules(uint _buyerEIN) public view {
        // check if token has designated values
        bool _designatedDefaultValues = true;
        if ((tokenData[msg.sender].minimumAge == 0) ||
            (tokenData[msg.sender].minimumNetWorth == 0) ||
            (tokenData[msg.sender].minimumSalary == 0)) {
            _designatedDefaultValues = false;
            }
        require(_designatedDefaultValues == true,
         "Token must have designated default values");

        // KYC restriction (not optional)
        require (buyerRegistryDetail[_buyerEIN].kycWhitelisted == true,
         "Buyer must be approved for KYC");

        // AML restriction
        if (tokenData[msg.sender].amlWhitelistingRequired == true) {
            require (buyerRegistryDetail[_buyerEIN].amlWhitelisted == true,
             "Buyer must be approved for AML");
        }

        // CFT restriction
        if (tokenData[msg.sender].cftWhitelistingRequired == true) {
            require (buyerRegistryDetail[_buyerEIN].cftWhitelisted == true,
             "Buyer must be approved for CFT");
        }

        // age restriction
        if (tokenData[msg.sender].minimumAge > 0) {
            uint256 _buyerAgeSeconds = now - buyerRegistryDetail[_buyerEIN].birthTimestamp;
            uint16 _buyerAgeYears = dateTime.getYear(_buyerAgeSeconds);
            require (_buyerAgeYears >= tokenData[msg.sender].minimumAge,
             "Buyer must reach minimum age");
        }

        // net-worth restriction
        if (tokenData[msg.sender].minimumNetWorth > 0) {
            require (buyerRegistryDetail[_buyerEIN].netWorth >= tokenData[msg.sender].minimumNetWorth,
             "Buyer must reach minimum net worth");
        }

        // salary restriction
        if (tokenData[msg.sender].minimumSalary > 0) {
            require (buyerRegistryDetail[_buyerEIN].salary >= tokenData[msg.sender].minimumSalary,
             "Buyer must  reach minimum salary");
        }

        // accredited investor status
        if (tokenData[msg.sender].accreditedInvestorStatusRequired == true) {
            require (buyerRegistryDetail[_buyerEIN].accreditedInvestorStatus == true,
             "Buyer must be an accredited investor");
        }

        // country/geography restrictions on ownership
        require (bannedCountries[msg.sender][buyerRegistryDetail[_buyerEIN].isoCountryCode] == false,
         "Country of Buyer must not be banned for token");

    }

}
