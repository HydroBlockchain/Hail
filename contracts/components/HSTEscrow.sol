pragma solidity ^0.5.0;

import '../interfaces/HydroInterface.sol';
//import '../HydroSecuritiesToken.sol';

/**
 * @title HydroEscrow
 * @notice Stores HYDRO inside as an escrow for HST issuing. This contracts stores any funds sent by the token creator and the funds that users pay to participate in the issuing. It distributes any refunds, and the corresponding dividends and interests to their receivers.
 * @author Fatima Castiglione Maldonado <castiglionemaldonado@gmail.com>
 */
contract HSTEscrow {
    uint256 public issuingEndingTimestamp;
    address public hydroSecurityTokenAddress;
    address public hydroTokenAddress;
    uint256 public totalHydroCapitalization;
    address payable public hydroCapitalReceiverAddress;
    HydroInterface public hydroToken;
    // HydroSecuritiesToken public hydroSecuritiesToken;


    modifier onlyHydroSecurityToken() {
        require(msg.sender == hydroSecurityTokenAddress, 'This function can only be executed by the original HydroSecurityToken');
        _;
    }

    /**
    * @notice Constructor
    * @dev    For the escrow to work properly, you need to set this variables.
    * @param  _issuingEndingTimestamp Time+Date when token issuing must stop
    * @param  _hydroSecurityTokenAddress The address of the token being issued
    * @param  _totalHydroCapitalization Total capitalization accepted, measured in Hydro
    * @param  _hydroCapitalReceiver The address of the capital receiver account
    */
    constructor(uint256 _issuingEndingTimestamp, address _hydroSecurityTokenAddress, uint256 _totalHydroCapitalization, address payable _hydroCapitalReceiver) public {
        require(_issuingEndingTimestamp > now, 'The token issuing must end after now');
        require(_hydroSecurityTokenAddress != address(0), 'You must set the token address');
        require(_totalHydroCapitalization > 0, 'The total capitalization must be larger than zero');
        require(_hydroCapitalReceiver != address(0), 'You must set a capital receiver');
        issuingEndingTimestamp = _issuingEndingTimestamp;
        hydroSecurityTokenAddress = msg.sender;
        // hydroSecuritiesToken = HydroSecuritiesToken(_hydroSecurityTokenAddress);
        hydroCapitalReceiverAddress = _hydroCapitalReceiver;
    }

    /**
    * @notice Send the collected capital to the capital receiver
    * @return uint8 The reason code: 0 means success.
    */
    function releaseCollectedCapital() public onlyHydroSecurityToken returns(uint8) {
        require(now >= issuingEndingTimestamp, 'You can only release funds after the token issuing has ended');
        uint256 hydroInsideThisContract = hydroToken.balanceOf(address(this));
        hydroToken.transfer(hydroCapitalReceiverAddress, hydroInsideThisContract);
        return(0);
    }
}
