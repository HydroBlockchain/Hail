pragma solidity ^0.5.0;


contract BONDS_PARAMS {
    uint256 public numberOfCapitalDues;
    uint256 public fixedInterestRate;
    uint256 public expirationDate;
    // Flag to set this configuration ready
    bool public EXT_PARAMS_ready;
    // Flags to set EXT_PARAMS_ready in Bonds
    bool ISSUER_PROPS_ready;
    bool BONDS_PROPS_ready;
}

contract UNITS_PARAMS {
	address payable public fundManager;
    uint256 public carriedInterestRate;
}

contract TOKEN_PARAMS {
	struct Investor {
        bool exists;
        uint256 hydroSent;
        uint256 lastPeriodPayed;
    }

    string public issuerName;
    string public registeredNumber;
    string public jurisdiction;

    mapping(uint256 => mapping(address => uint256)) public balanceAt;
    mapping(address => uint256) public lastBalance;
    mapping(uint256 => uint256) public profits;
    mapping(uint256 => Investor) public investors;
    uint256 public issuedTokens;
}



contract PaymentSystem is BONDS_PARAMS, UNITS_PARAMS, TOKEN_PARAMS {

    // using SafeMath for uint256;

    enum STOTypes {
        SHARES, UNITS, BONDS
    }

    STOTypes public stoType;

    event SharesPayed(
        uint256 indexed investorEin, 
        uint256 periodToPay, 
        uint256 periodProfits, 
        uint256 investorParticipationRate,
        uint256 paymentForInvestor
        );

	event CapitalPayed(
		uint256 indexed investorEin, 
		uint256 periodToPay, 
		uint256 capitalPayed, 
		uint256 investorParticipationRate);

    event PeriodNotified(
        uint256 indexed period,
        uint256 profits
        );

    // PUBLIC SETTERS FOR SETUP STAGE, only for admin -----------------------------------------------------------

    function setIssuerProperties(
        string memory _issuerName,
        string memory _registeredNumber,
        string memory _jurisdiction,
        address payable _fundManager, // Can be 0x0 for Shares and Bonds
        uint256 _carriedInterestRate // Can be 0 for Shares and Bonds
        ) public
    {
    	onlyTokenOwner();
    	onlySetupStage();

        if (stoType == STOTypes.UNITS) {
            require(_fundManager != address(0x0), "fundManager address is required");
            require(_carriedInterestRate > 0, "carriedInterestRate should be greater than zero");
        }

        // Set properties
        issuerName = _issuerName;
        registeredNumber = _registeredNumber;
        jurisdiction = _jurisdiction;
        fundManager = _fundManager;
        carriedInterestRate = _carriedInterestRate;

        ISSUER_PROPS_ready = true;

        if (stoType != STOTypes.BONDS || BONDS_PROPS_ready) {
            EXT_PARAMS_ready = true; // Allow passing to Prelaunch stage
        }
    }

    // Extra data only for Bonds type

    function setBondsProperties(
    	uint256 _numberOfCapitalDues, // 1 for single capital at expiration date
    	uint256 _fixedInterestRate, // It can be 0 for variable interest rate
    	uint256 _expirationDate // It can be 0 to be setted later
    	) public
    {
    	onlyTokenOwner();
    	onlySetupStage();

        require(_numberOfCapitalDues > 0, "Number of capital dues should be greater than zero");

        // Set bonds properties
        numberOfCapitalDues = _numberOfCapitalDues;
        fixedInterestRate = _fixedInterestRate;
        expirationDate = _expirationDate;

        BONDS_PROPS_ready = true;

        if (ISSUER_PROPS_ready) {
            EXT_PARAMS_ready = true; // Allow passing to Prelaunch stage
        }
    }

    // For Bonds. It let set expirationDate if it was 0

    function setExpirationDate(uint256 _expirationDate) public {
    	onlyTokenOwner();
    	require(expirationDate == 0, "Expiration date can not be modified more than once");
    	expirationDate = _expirationDate;
    }


    // PUBLIC FUNCTION FOR INVESTORS --------------------------------------------------------------------------

    function claimPayment()
        public
    {
        uint256 _ein = _getEIN(msg.sender);
        uint256 _periodToPay = investors[_ein].lastPeriodPayed + 1;
        require(_periodToPay <= getPeriod(), "There is no period to pay yet");

        investors[_ein].lastPeriodPayed = _periodToPay;

        uint256 _userBalance = _balanceAt(_periodToPay, msg.sender);
        uint256 _participationRate = _userBalance * 1 ether / issuedTokens;
        uint256 _paymentForInvestor = 
        	(fixedInterestRate > 0) ? fixedInterestRate : profits[_periodToPay] // Bonds with fixed interest exception
        	* _participationRate / 1 ether;

        if (_paymentForInvestor > 0) {
            require(_transferHydroToken(msg.sender, _paymentForInvestor), "Error while releasing Tokens for interest payment");
        }

        if (stoType == STOTypes.BONDS) {
        	require(_periodToPay <= numberOfCapitalDues, "All periods has been payed");
        	if (numberOfCapitalDues == 1) {
        		require(expirationDate > 0, "Expiration date has not been set yet");
        		require(expirationDate < now, "Expiration date has not arrived yet");
        	}
        	uint256 _capitalPayment = _userBalance / numberOfCapitalDues;

        	if (_capitalPayment > 0) {
            	require(_transferHydroToken(msg.sender, _capitalPayment), "Error while releasing Tokens for capital payment");
        	} 

        	emit CapitalPayed(_ein, _periodToPay, _capitalPayment, _participationRate);
        }

       emit SharesPayed(_ein, _periodToPay, profits[_periodToPay], _participationRate, _paymentForInvestor);
    }


    // INTERNAL FUNCTIONS ---------------------------------------------------------------------

    function _balanceAt(uint256 _period, address _address) private view returns(uint256) {
        return balanceAt[
        	_period > lastBalance[_address] ? lastBalance[_address] : _period
        ][_address];
    }

    // Modifiers as functions to avoid compilation bloat

    function onlyTokenOwner() private view {
		require(_getEIN(msg.sender) == _getTokenEinOwner(), "Only for token owner");
	}

	function onlySetupStage() private view {
		require(tokenInSetupStage(), "Only at Setup stage");
	}
	

    // Dummy functions (to be overwritten by main contract)
    function getPeriod() public view returns(uint256);
    function _getEIN(address) private view returns(uint256);
    function _getTokenEinOwner() private view returns(uint256);
    function tokenInSetupStage() private view returns(bool);
    function _transferHydroToken(address, uint256) private returns(bool);
    function _hydroTokensBalance() private view returns(uint256);

}