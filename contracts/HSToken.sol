pragma solidity ^0.5.0;

import './interfaces/HSTBuyerRegistryInterface.sol';
import './interfaces/HydroInterface.sol';
import './interfaces/IdentityRegistryInterfaceShort.sol';
import './zeppelin/math/SafeMath.sol';
import './modules/PaymentSystem.sol';

// Rinkeby testnet addresses
// HydroToken: 0x4959c7f62051d6b2ed6eaed3aaee1f961b145f20
// IdentityRegistry: 0xa7ba71305be9b2dfead947dc0e5730ba2abd28ea


interface Raindrop {
    function authenticate(address _sender, uint _value, uint _challenge, uint _partnerId) external;
}

interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external;
}

/**
* @dev We use contracts to store main variables, because Solidity can not handle so many individual variables
*/

contract MAIN_PARAMS {
    bool public MAIN_PARAMS_ready;

    uint256 public hydroPrice;
    uint256 public lockEnds; // Ending date of locking period
    uint256 public maxSupply;
    uint256 public escrowLimitPeriod;
}

contract STO_FLAGS {
    bool public STO_FLAGS_ready;

    bool public LIMITED_OWNERSHIP;
    bool public PERIOD_LOCKED;  // Locked period active or inactive
    bool public PERC_OWNERSHIP_TYPE; // is percentage of ownership limited?
    bool public HYDRO_AMOUNT_TYPE; // is Hydro amount limited?
    bool public WHITELIST_RESTRICTED;
    bool public BLACKLIST_RESTRICTED;
}

contract STO_PARAMS {
    bool public STO_PARAMS_ready;
    // @param percAllowedTokens: 100% = 1 ether, 50% = 0.5 ether
    uint256 public percAllowedTokens; // considered if PERC_OWNERSHIP_TYPE
    uint256 public hydroAllowed; // considered if HYDRO_AMOUNT_TYPE
    uint256 public lockPeriod; // in days
    uint256 public minInvestors;
    uint256 public maxInvestors;
    address public hydroOracle;
}

contract STO_Interests {
    uint256 public marketStarted; // Date for market stage
    uint256[] internal periods;
}


/**
 * @title HSToken
 *
 * @notice The Hydro Security Token is part of the Hydro Security Tokens Framework,
 * a system to allow organizations to create their own Security Tokens,
 * related to their Snowflake identities, serviced by external KYC, AML and CFT services,
 * and restrainable by some rules.
 *
 * @author Juan Livingston <juanlivingston@gmail.com>
 */

contract HSToken is MAIN_PARAMS, STO_FLAGS, STO_PARAMS, STO_Interests, PaymentSystem {

    using SafeMath for uint256;

    enum Stage {
        SETUP, PRELAUNCH, PRESALE, SALE, LOCK, MARKET, FINALIZED
    }

    // State Memory
    Stage public stage; // SETUP, PRELAUNCH, PRESALE, SALE, LOCK, MARKET, FINALIZED


    // Lock state
    bool public locked; // Mark if token transfers are locked


	// Main parameters
    uint256 public registrationDate; // Token creation and registration date
    uint256 public id; // Unique HSToken id
    bytes32 public name;
    string public description;
    bytes32 public symbol;
    uint8 public decimals;
    address payable public Owner;
    uint256 public einOwner;
    address public createdBy;

    // uint256 public issuedTokens; // Moved to payment module
    uint256 public hydroReceived;
    uint256 public numberOfInvestors;
    uint256 public hydrosReleased; // Number of Hydros released by owner

    address public raindropAddress;

    // address InterestSolver;


    // mappings -----------------------------------------------------------------

    // EIN => yes/no
    mapping(uint256 => bool) public whitelist;

    // EIN => yes/no
    mapping(uint256 => bool) public blacklist;

    // EIN => yes/no
    mapping(uint256 => bool) public freezed;

    // ERC20 allowance
    mapping(address => mapping(address => uint256)) public allowed;

    // EIN => Investor Data
    mapping(uint256 => Investor) public investors;

    // Balances
    mapping(address => uint256) public balance;
    // This was moved to the payment module
    // mapping(uint256 => mapping(address => uint256)) public balanceAt;

    // Declaring interfaces
    IdentityRegistryInterface public IdentityRegistry;
    HydroInterface public HydroToken;
    HSTBuyerRegistryInterface public BuyerRegistry;


    // events -----------------------------------------------------------------

  /**
   * @notice Triggered when Hydro Security Token is created
   */
    event HydroSTCreated(
        uint256 indexed id,
        bytes32 name,
        bytes32 symbol,
        uint8 decimals,
        uint256 einOwner
        );

  /**
   * @notice Triggered when payment period boundaries are appointed
   */
    event PaymentPeriodBoundariesAdded(
    	uint256[] _periods
    	);

  /**
   * @notice Triggered when Hydro Security Token is sold
   */
    event Sell(address indexed _owner, uint256 _amount);

  /**
   * @notice Triggered when Hydro Security Token is transferred
   */
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _amount
    );

  /**
   * @notice Triggered when user gives approval for another user
   */
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _amount
    );


    /**
    * @dev Modifiers are paired with functions to optimize bytecode size at deployment time
    */


  /**
  * @notice Throws if buyer registry does not approve the transaction
  */
    modifier checkRules(address addr) {
        _checkRules(addr);
        _;
    }
    function _checkRules(address addr) private view {
        BuyerRegistry.checkRules(IdentityRegistry.getEIN(addr));
    }

  /**
  * @notice Throws if called while inside escrow period
  */
    modifier escrowReleased() {
        _escrowReleased();
        _;
    }
    function _escrowReleased() private legalStatusOK() view {
        require(escrowLimitPeriod < block.timestamp, "Escrow limit period is still active");
    }

  /**
   * @notice verify if source and target addresses are unfreezed
   *
   * @param _from source address
   * @param _to target address
   */
    modifier isUnfreezed(address _from, address _to) {
        _isUnfreezed(_from, _to);
        _;
    }
    function _isUnfreezed(address _from, address _to) private view {
        require(!freezed[IdentityRegistry.getEIN(_to)], "Target EIN is freezed");
        require(!freezed[IdentityRegistry.getEIN(_from)], "Source EIN is freezed");
    }

  /**
  * @notice Throws if called while token is locked
  */
    modifier isUnlocked() {
        _isUnlocked();
        _;
    }
    function _isUnlocked() private view {
        require(!locked, "Token locked");
        if (PERIOD_LOCKED) require (block.timestamp > lockEnds, "Locked period active");
    }

  /**
  * @notice Check if token has legal approval
  */
    modifier legalStatusOK() {
        _legalStatusOK();
        _;
    }
    function _legalStatusOK() private view {
        require(BuyerRegistry.getTokenLegalStatus(address(this)), "Token must have legal approval");
    }

  /**
  * @notice Throws if called while in a non-active stage
  */
    modifier onlyActive() {
        _onlyActive();
        _;
    }
    function _onlyActive() private view {
        require(
            stage == Stage.PRESALE ||
            stage == Stage.SALE ||
            stage == Stage.MARKET,
            "Not in active stage"
            );
    }

  /**
   * @notice Qualify functions so only the administrator can execute them
   */
    modifier onlyAdmin() {
        _onlyAdmin();
        _;

    }
    function _onlyAdmin() private view {
        // Check if EIN of sender is the same as einOwner
        require(IdentityRegistry.getEIN(msg.sender) == einOwner, "Only administrators can execute this function");
    }

  /**
   * @notice verify if the token is in the market stage
   */
    modifier onlyInMarketStage() {
        _onlyInMarketStage();
        _;
    }
    function _onlyInMarketStage() private view {
        require(stage == Stage.MARKET, "Token is not currently in market stage");
        require(!locked, "Token is currently locked");
        if (PERIOD_LOCKED) require (block.timestamp > lockEnds, "Locked period is currently active");
    }

  /**
   * @notice verify if the token is in the setup stage
   */
    modifier onlyInSetupStage() {
        _onlyInSetupStage();
        _;
    }
    function _onlyInSetupStage() private view {
        require(stage == Stage.SETUP && (block.timestamp - registrationDate) < (15 * 24 * 60 * 60), "Token is not currently in setup stage");
    }

    
  /**
   * @notice Token constructor
   *
   * @param _id Token ID
   * @param _stoType Token type (0: Shares, 1: Units, 3: Bonds)
   * @param _name Token name
   * @param _description Token description
   * @param _symbol Token symbol
   * @param _decimals Token decimals
   * @param _hydroToken Address of the Hydro Token contract
   * @param _identityRegistry Address of the Identity Registry contract
   * @param _buyerRegistry Address of the Buyer Registry contract
   * @param _owner Address of the Token owner
   */
    constructor(
        uint256 _id,
        uint8 _stoType,
        bytes32 _name,
        string memory _description,
        bytes32 _symbol,
        uint8 _decimals,
        address _hydroToken,
        address _identityRegistry,
        address _buyerRegistry,
        address payable _owner
    ) public {
        id = _id;
        name = _name;
        description = _description;
        symbol = _symbol;
        decimals = _decimals;

        setSTOType(_stoType);

        registrationDate = block.timestamp;
        // locked = true;

        // State Memory
        stage = Stage.SETUP;

        periods.push(block.timestamp);

        // Links to Modules
        HydroToken = HydroInterface(_hydroToken);
        // 0x4959c7f62051D6b2ed6EaeD3AAeE1F961B145F20
        IdentityRegistry = IdentityRegistryInterface(_identityRegistry);
        // 0xa7ba71305bE9b2DFEad947dc0E5730BA2ABd28EA
        BuyerRegistry = HSTBuyerRegistryInterface(_buyerRegistry);
        // raindropAddress = _RaindropAddress;

        Owner = _owner;
        einOwner = IdentityRegistry.getEIN(Owner);
        createdBy = msg.sender;

        emit HydroSTCreated(id, name, symbol, decimals, einOwner);
    }


    // ADMIN SETUP FUNCTIONS -----------------------------------------------------------------

  /**
   * @notice Set main parameters for the token
   *
   * @param _hydroPrice The price of the Hydro token for calculations
   * @param _lockEnds Date in which token lock period ends
   * @param _maxSupply Maximum supply of the token
   * @param _escrowLimitPeriod Lenght of escrow period in seconds
   */
    function set_MAIN_PARAMS(
        uint256 _hydroPrice,
        uint256 _lockEnds,
        uint256 _maxSupply,
        uint256 _escrowLimitPeriod
    ) public onlyAdmin() onlyInSetupStage() {
        // Validations
        require(
            _hydroPrice > 0 &&
            _lockEnds > block.timestamp &&
            _maxSupply > 10000 &&
            _escrowLimitPeriod > (10 * 24 * 60 * 60),
            "Incorrect input data"
        );
        require(!MAIN_PARAMS_ready, "Params already setted");
        // Load values
        hydroPrice = _hydroPrice;
        lockEnds = _lockEnds; // Date of end of locking period
        maxSupply = _maxSupply;
        escrowLimitPeriod = _escrowLimitPeriod;
        // Set flag
        MAIN_PARAMS_ready = true;
    }

  /**
   * @notice Set flags for the token
   *
   * @param _LIMITED_OWNERSHIP The price of the Hydro token for calculations
   * @param _PERIOD_LOCKED Date in which token lock period ends
   * @param _PERC_OWNERSHIP_TYPE Maximum supply of the token
   * @param _HYDRO_AMOUNT_TYPE Will the token be restricted by amount of hydrotokens?
   * @param _WHITELIST_RESTRICTED Will the token be restricted by a whitelist?
   * @param _BLACKLIST_RESTRICTED Will the token be restricted by a blacklist?
   */
    function set_STO_FLAGS(
        bool _LIMITED_OWNERSHIP,
        bool _PERIOD_LOCKED,
        bool _PERC_OWNERSHIP_TYPE,
        bool _HYDRO_AMOUNT_TYPE,
        bool _WHITELIST_RESTRICTED,
        bool _BLACKLIST_RESTRICTED
    ) public onlyAdmin() onlyInSetupStage() {
        require(!STO_FLAGS_ready, "Flags already setted");
        // Load values
        LIMITED_OWNERSHIP = _LIMITED_OWNERSHIP;
        PERIOD_LOCKED = _PERIOD_LOCKED;
        PERC_OWNERSHIP_TYPE = _PERC_OWNERSHIP_TYPE;
        HYDRO_AMOUNT_TYPE = _HYDRO_AMOUNT_TYPE;
        WHITELIST_RESTRICTED = _WHITELIST_RESTRICTED;
        BLACKLIST_RESTRICTED = _BLACKLIST_RESTRICTED;
        // Set flag
        STO_FLAGS_ready = true;
    }

  /**
   * @notice Set flags for the token
   *
   * @param _percAllowedTokens if _PERC_OWNERSHIP_TYPE is true, this will be the percentage
   * @param _hydroAllowed if _HYDRO_AMOUNT_TYPE is true, this will be the limit?
   * @param _lockPeriod if _PERIOD_LOCKED is true, this will be the period
   * @param _minInvestors minimum number of investors allowed
   * @param _maxInvestors maximum number of investors allowed
   * @param _hydroOracle address of oracle to update hydro price of token (if any)
   */
    function set_STO_PARAMS(
        uint256 _percAllowedTokens,
        uint256 _hydroAllowed,
        uint256 _lockPeriod,
        uint256 _minInvestors,
        uint256 _maxInvestors,
        address _hydroOracle
    ) public onlyAdmin() onlyInSetupStage() {
        require(!STO_PARAMS_ready, "Params already setted");
        require(STO_FLAGS_ready, "STO_FLAGS has not been set");
        // Load values
        percAllowedTokens = _percAllowedTokens;
        hydroAllowed = _hydroAllowed;
        lockPeriod = _lockPeriod;
        minInvestors = _minInvestors;
        maxInvestors = _maxInvestors;
        hydroOracle = _hydroOracle;
        // Set flag
        STO_PARAMS_ready = true;
    }


    // ADMIN CHANGING STAGES -------------------------------------------------------------------

  /**
   * @notice Move token to pre-launch stage
   */
    function stagePrelaunch() public onlyAdmin() onlyInSetupStage() {
        require(MAIN_PARAMS_ready, "MAIN_PARAMS not setted");
        require(STO_FLAGS_ready, "STO_FLAGS not setted");
        require(STO_PARAMS_ready, "STO_PARAMS not setted");
        require(EXT_PARAMS_ready, "EXT_PARAMS not setted"); // Parameters required for payment module
        stage = Stage.PRELAUNCH;
    }

  /**
   * @notice Move token to pre-sale stage
   */
    function stagePresale() public onlyAdmin() legalStatusOK() {
    	  require(stage == Stage.PRELAUNCH, "Stage should be Prelaunch");
        stage = Stage.PRESALE;
    }

  /**
   * @notice Move token to sale stage
   */
    function stageSale() public onlyAdmin() {
    	require(stage == Stage.PRESALE, "Stage should be Presale");
        stage = Stage.SALE;
    }

  /**
   * @notice Move token to lock stage
   */
    function stageLock() public onlyAdmin() {
    	require(stage == Stage.SALE, "Stage should be Sale");
        require(numberOfInvestors >= minInvestors, "Number of investors has not reached the minimum");
        stage = Stage.LOCK;
    }

  /**
   * @notice Move token to market stage
   */
    function stageMarket() public onlyAdmin() {
    	require(stage == Stage.LOCK, "Stage should be Lock");
    	stage = Stage.MARKET;
    	marketStarted = block.timestamp;
    }


    // ADMIN GENERAL FUNCTIONS ----------------------------------------------------------------

  /**
   * @notice Get the EIN of the token owner
   *
   * @return The EIN of the token owner
   */
    function getTokenEINOwner() public view returns(uint) {
        return einOwner;
    }

  /**
   * @notice Get the address of the token owner
   *
   * @return The address of the token owner
   */
    function getTokenOwner() public view returns(address) {
        return Owner;
    }

  /**
   * @notice Set the date to end the lock-up period
   *
   * @param _lockEnds The date in which the lock-up period ends
   */
    function setLockupPeriod(uint256 _lockEnds) public onlyAdmin() {
        // Remove lock period
        if (_lockEnds == 0) {
            PERIOD_LOCKED = false;
            lockEnds = 0;
            return;
            }
        // Add lock period
        require(_lockEnds > block.timestamp + 24 * 60 * 60, "Lock ending should be at least 24 hours in the future");
        PERIOD_LOCKED = true;
        lockEnds = _lockEnds;
    }

  /**
   * @notice Set the address for the buyer registry
   *
   * @dev Token must be in the setup stage
   *
   * @param _newBuyerRegistry The address for the buyer registry
   */
    function changeBuyerRegistry(address _newBuyerRegistry) public onlyAdmin() {
    	require(stage == Stage.SETUP, "Stage should be Setup to change this registry");
		BuyerRegistry = HSTBuyerRegistryInterface(_newBuyerRegistry);
    }

  /**
   * @notice Lock token transfers
   */
    function lock() public onlyAdmin() {
        locked = true;
    }

  /**
   * @notice Unlock token transfers
   */
    function unLock() public onlyAdmin() {
        locked = false;
    }

  /**
   * @notice Add one or many EIN/s to the whitelist
   */
    function addWhitelist(uint256[] memory _einList) public onlyAdmin() {
        for (uint i = 0; i < _einList.length; i++) {
          whitelist[_einList[i]] = true;
        }
    }

  /**
   * @notice Add one or many EIN/s to the blacklist
   */
    function addBlacklist(uint256[] memory _einList) public onlyAdmin() {
        for (uint i = 0; i < _einList.length; i++) {
          blacklist[_einList[i]] = true;
        }
    }

  /**
   * @notice Remove one or many EIN/s from the whitelist
   */
    function removeWhitelist(uint256[] memory _einList) public onlyAdmin() {
        for (uint i = 0; i < _einList.length; i++) {
          whitelist[_einList[i]] = false;
        }

    }

  /**
   * @notice Remove one or many EIN/s from the blacklist
   */
    function removeBlacklist(uint256[] memory _einList) public onlyAdmin() {
        for (uint i = 0; i < _einList.length; i++) {
          blacklist[_einList[i]] = false;
        }
    }

  /**
   * @notice Freeze token
   */
    function freeze(uint256[] memory _einList) public onlyAdmin() {
        for (uint i = 0; i < _einList.length; i++) {
          freezed[_einList[i]] = true;
        }
    }

  /**
   * @notice Unfreeze token
   */
    function unFreeze(uint256[] memory _einList) public onlyAdmin() {
        for (uint i = 0; i < _einList.length; i++) {
          freezed[_einList[i]] = false;
        }
    }

  /**
   * @notice Appoint boundaries for payment periods
   *
   * @param _periods End date/s for the payment period/s
   */
    function addPaymentPeriodBoundaries(uint256[] memory _periods) public onlyAdmin() {
        require(_periods.length > 0, "There should be at least one period set");
        for (uint i = 0; i < _periods.length; i++) {
          require(periods[periods.length-1] < _periods[i], "New periods must be after last period registered");
          periods.push(_periods[i]);
        }
        emit PaymentPeriodBoundariesAdded(_periods);
    }

  /**
   * @notice Get boundaries for payment periods
   *
   * @return End date/s for the payment period/s
   */
    function getPaymentPeriodBoundaries() public view returns(uint256[] memory) {
    	return periods;
    }

  /**
   * @notice Appoint address for the oracle
   *
   * @param _newAddress Address for the oracle
   */
    function addHydroOracle(address _newAddress) public onlyAdmin() {
    	hydroOracle = _newAddress;
    }

  /**
   * @notice Release profit, in Hydros
   *
   * @dev Can only be performed after the escrow is released
   */
    function releaseHydroTokens() public escrowReleased() onlyAdmin() {
        uint256 thisBalance = HydroToken.balanceOf(address(this));
        require(thisBalance > 0, "There are no HydroTokens in this account");
        hydrosReleased = hydrosReleased + thisBalance;
        require(HydroToken.transfer(Owner, thisBalance), "Error while releasing Tokens");
    }


    // PUBLIC FUNCTIONS FOR INVESTORS -----------------------------------------------------------------

  /**
   * @notice Release profit, in Hydros
   *
   * @dev Can only be performed after the escrow is released
   *
   * @param _amount Number of tokens to be bought
   *
   * @return True if everything goes well
   */
    function buyTokens(uint256 _amount)
        public checkRules(msg.sender) onlyActive() payable
        returns(bool)
    {
        uint256 total;
        uint256 _ein = IdentityRegistry.getEIN(msg.sender);

        if (!investors[_ein].exists) {
            numberOfInvestors++;
            investors[_ein].exists = true;
            require(numberOfInvestors <= maxInvestors || maxInvestors == 0, "Maximum number of investors reached");
        }

        // Check for limits
        if (HYDRO_AMOUNT_TYPE) {
            require(hydroReceived.add(_amount) <= hydroAllowed, "Hydro amount exceeded");
        }

        // Check with KYC and AML providers
        //BuyerRegistry.checkRules(_ein);

        // If Stage is PRESALE, check with whitelist and blacklist
        if (stage == Stage.PRESALE) {
            if (WHITELIST_RESTRICTED) _checkWhitelist(_ein);
            if (BLACKLIST_RESTRICTED) _checkBlacklist(_ein);
        }

        // Calculate total
        total = _amount.mul(hydroPrice) / 1 ether;
        // Adjust state
        investors[_ein].hydroSent = investors[_ein].hydroSent.add(_amount);
        hydroReceived = hydroReceived.add(_amount);
        issuedTokens = issuedTokens.add(total);
        balance[msg.sender] = balance[msg.sender].add(total);
        balanceAt[0][msg.sender] = balance[msg.sender];

        // Check with maxSupply
        require(issuedTokens <= maxSupply, "Max supply of Tokens is exceeded");

        // Check for ownership percentage
        if (PERC_OWNERSHIP_TYPE) {
            require ((issuedTokens.mul(1 ether) / maxSupply) < percAllowedTokens,
                "Perc ownership exceeded");
        }

        // Transfer Hydrotokens from buyer to this contract
        require(HydroToken.transferFrom(msg.sender, address(this), _amount),
            "Hydro transfer was not possible");

        emit Sell(msg.sender, total);
        return true;
    }


    // To be accesed by modules ---------------------------------------------------------------

    // FUNCTIONS

  /**
   * @notice Transfer token
   *
   * @dev Can only be performed after the escrow is released
   *
   * @param _address Address to transfer to
   * @param _payment Number of token to transfer
   */
    function _transferHydroToken(address _address, uint256 _payment) private returns(bool) {
        return HydroToken.transfer(_address, _payment);
    }

    // GETTERS

  /**
   * @notice Get the EIN for an address
   *
   * @param _address Address to get the EIN for
   * @return EIN corresponding to the input address
   */
    function _getEIN(address _address) private view returns(uint256) {
        return IdentityRegistry.getEIN(_address);
    }

  /**
   * @notice Get current stage for the token
   *
   * @return Number of current stage (see Stage enumeration)
   */
    function _getStage() private view returns(uint256) {
    	return uint(stage);
    }

  /**
   * @notice Get the EIN for the token owner
   *
   * @return EIN corresponding to the token owner
   */
    function _getTokenEinOwner() private view returns(uint256) {
    	return einOwner;
    }

  /**
   * @notice Get current Hydro tokens balance for the token contract
   *
   * @return Number of Hydro tokens held by the token contract
   */
    function _hydroTokensBalance() private view returns(uint256) {
    	return HydroToken.balanceOf(address(this));
    }


    // Token ERC-20 wrapper ---------------------------------------------------------------------

  /**
   * @notice Transfer tokens to address
   *
   * @param _to Address to transfer tokens to
   * @param _amount Amount of tokens to be transferred
   *
   * @return True if all goes well
   */
    function transfer(address _to, uint256 _amount)
     public checkRules(_to) isUnfreezed(msg.sender, _to) onlyInMarketStage() returns(bool success) {
        _doTransfer(msg.sender, _to, _amount);
        return true;
    }

  /**
   * @notice Transfer from one address to another
   *
   * @param _from Address to transfer tokens from
   * @param _to Address to transfer tokens to
   * @param _amount Amount of tokens to be transferred
   *
   * @return True if all goes well
   */
    function transferFrom(address _from, address _to, uint256 _amount)
     public checkRules(_to) isUnfreezed(_from, _to) onlyInMarketStage() returns(bool success) {
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        _doTransfer(_from, _to, _amount);
        return true;
    }

  /**
   * @notice Get current tokens balance for an address
   *
   * @return Number of Hydro tokens held by the specified address
   */
    function balanceOf(address _from) public view returns(uint256) {
        return balance[_from];
    }

  /**
   * @notice Approve another address to make transfers in your name
   *
   * @param _spender Address to allow token transfers
   * @param _amount Amount of tokens to be allowed
   *
   * @return True if all goes well
   */
    function approve(address _spender, uint256 _amount) public returns(bool success) {
        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender,0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require(_amount == 0 || allowed[msg.sender][_spender] == 0, "Approved amount should be zero before changing it");
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

  /**
   * @notice ERC20 Approveandcall function
   *
   * @param _spender Address to allow token transfers
   * @param _value quantity of tokens
   * @param _extraData extra data (if any)
   *
   * @return True if all goes well
   */
    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
    }

  /**
   * @notice Raindrop authentication
   */
    function authenticate(uint _value, uint _challenge, uint _partnerId) public {
        Raindrop raindrop = Raindrop(raindropAddress);
        raindrop.authenticate(msg.sender, _value, _challenge, _partnerId);
        _doTransfer(msg.sender, Owner, _value);
    }

  /**
   * @notice Raindrop authentication
   */
    function _doTransfer(address _from, address _to, uint256 _amount) private {
        uint256 _period = getPeriod();
        balance[_to] = balance[_to].add(_amount);
        balance[_from] = balance[_from].sub(_amount);
        balanceAt[_period][_to] = balance[_to];
        balanceAt[_period][_from] = balance[_from];
        lastBalance[_from] = _period;
        lastBalance[_to] = _period;
        emit Transfer(_from, _to, _amount);
    }

    // PUBLIC GETTERS --------------------------------------------------------------------------

  /**
   * @notice Answer if token is locked
   *
   * @return true if locked, false if not
   */
    function isTokenLocked() public view returns(bool) {
        if (locked) return true;
        if (PERIOD_LOCKED && block.timestamp < lockEnds) return true;
        return false;
    }

  /**
   * @notice Answer if token is alive & kicking
   *
   * @return true if token is functional, false if it was abandoned in setup stage?
   */
    function isTokenAlive() public view returns(bool) {
        if (stage != Stage.SETUP) return true;
        if (!tokenInSetupStage()) return false;
        return true;
    }

  /**
   * @notice get timestamp for current network block (for testing purposes)
   *
   * @return timestamp for the current network block
   */
    function getNow() public view returns(uint256) {
    	return block.timestamp;
    }

  /**
   * @notice get current running period
   *
   * @return next period to come
   */
    function getPeriod() public view returns(uint256) {
        if (periods.length < 2) return 0;
        for (uint i = 1; i < periods.length; i++) {
          if (periods[i] > block.timestamp) return i-1;
        }
        return periods[periods.length-1];
    }


    // FUNCTIONS TO BE USED EXCLUSIVELY BY ORACLES --------------------------------------------------------------------

  /**
   * @notice update the Hydro token price in dollars
   *
   * @param _newPrice new Hydro token price in dollars
   */
    function updateHydroPrice(uint256 _newPrice) external {
    	require(msg.sender == hydroOracle, "Only registered Oracle can set Hydro price");
    	hydroPrice = _newPrice;
    }

  /**
   * @notice notify the token about profits for the current period
   *
   * @param _profits profits in HydroToken
   */
    function notifyPeriodProfits(uint256 _profits) public {
        require(msg.sender == hydroOracle, "Only registered oracle can notify profits");
        require(_profits > 0, "Profits has to be greater than zero");
        uint256 _periodToPay = getPeriod();
        require(profits[_periodToPay] == 0, "Period already notified");

        profits[_periodToPay] = _profits;

        if (stoType == STOTypes.UNITS) {
            uint256 _paymentForManager = _profits.mul(carriedInterestRate) / 1 ether;
            require(_transferHydroToken(msg.sender, _paymentForManager), "Error while releasing Tokens");
        }

        emit PeriodNotified(_periodToPay, _profits);
    }


    // PRIVATE FUNCTIONS --------------------------------------------------------------------

  /**
   * @notice set the type for the token to determine
   *         which of the following securities it represents:
   *            0: Shares
   *            1: Units
   *            3: Bonds
   *
   * @param _stoType token type
   */
    function setSTOType(uint8 _stoType) private {
        require(_stoType < 3, "STO Type not recognized. 0: Shares, 1: Units, 3: Bonds");
        stoType = STOTypes(_stoType);
    }

  /**
   * @notice verify if token is in the setup stage
   *
   * @return true if yes, false if not
   */
    function tokenInSetupStage() private view returns(bool) {
        // Stage is SETUP and 15 days to complete setup has not passed yet
        return(stage == Stage.SETUP && (block.timestamp - registrationDate) < (15 * 24 * 60 * 60));
    }

  /**
   * @notice check if the EIN for a user is in the white list
   *
   * @param _einUser the EIN for the user in question
   */
    function _checkWhitelist(uint256 _einUser) private view {
        require(whitelist[_einUser], "EIN address not in whitelist");
    }

  /**
   * @notice check if the EIN for a user is in the black list
   *
   * @param _einUser the EIN for the user in question
   */
    function _checkBlacklist(uint256 _einUser) private view {
        require(!blacklist[_einUser], "EIN address is blacklisted");
    }

}
