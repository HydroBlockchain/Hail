pragma solidity ^0.5.0;

import '../interfaces/IdentityRegistryInterfaceShort.sol';
import '../zeppelin/ownership/Ownable.sol';

// DONE
// import relevant Snowflake contract
// contructor
// function isOwner()
// add getter and setter for Identity Registry address
// check that Identity Registry address cannot be zero for any operation to work

// TO DO
//

/**
 * @title SnowflakeOwnable
 * @notice Snowflake-based authorizations
 *
 * @dev The SnowflakeOwnable contract stores the EIN of the owner of a contract, and provides basic authorization functions, not based on an address as it is usual (think of "Ownable") but based on an EIN. This simplifies the implementation of "user permissions" when using Snowflakes.
 *
 * @author Fatima Castiglione Maldonado <castiglionemaldonado@gmail.com>
 */
contract SnowflakeOwnable is Ownable {

    //address private _owner;
    uint public ownerEIN;

    // access identity registry to get EINs for addresses
    address identityRegistryAddress;
    IdentityRegistryInterface public identityRegistry;

    /**
    * @notice Emit when setting address for the Identity Registry
    * @param  _identityRegistryAddress The address of the Identity Registry
    */
    event IdentityRegistryWasSet(address _identityRegistryAddress);

    /**
    * @notice Emit when setting EIN for the first time or from status owner EIN = 0
    * @param  _owner The EIN of the owner
    */
    event OwnerWasSet(uint _owner);

    /**
    * @notice Emit when transferring ownership
    * @param  _previousOwnerEIN The EIN of the previous owner
    * @param  _newOwnerEIN The EIN of the new owner
    */
    event OwnershipTransferred(uint _previousOwnerEIN, uint _newOwnerEIN);


    /**
    * @notice Throws if called by any account other than the owner
    * @dev This works on EINs, not on addresses
    */
    modifier onlySnowflakeOwner() {
        _onlySnowflakeOwner();
        _;
    }
    function _onlySnowflakeOwner() private view {
        require(isEINowner(), "Must be the EIN owner to call this function");
    }


    /**
    * @notice Set the address for the Identity Registry
    * @dev Also set the EIN of the owner
    *
    * @param _identityRegistryAddress The address of the IdentityRegistry contract
    */
    //function setIdentityRegistryAddress(address _identityRegistryAddress) public onlyOwner {
    function setIdentityRegistryAddress(address _identityRegistryAddress) public {
        // check required data
        require(_identityRegistryAddress != address(0), '2. The identity registry address is required');
        IdentityRegistryInterface _identityRegistry = IdentityRegistryInterface(_identityRegistryAddress);
        uint _ownerEIN = _identityRegistry.getEIN(msg.sender);
        require(_ownerEIN != 0, 'The caller must have an EIN');
        // set data
        identityRegistryAddress = _identityRegistryAddress;
        identityRegistry = _identityRegistry;
        ownerEIN = _ownerEIN;
        // emit events
        emit IdentityRegistryWasSet(_identityRegistryAddress);
        emit OwnerWasSet(ownerEIN);
    }

    /**
    * @notice Get the address for the Identity Registry
    * @return The address of the IdentityRegistry contract
    */
    function getIdentityRegistryAddress() public view returns(address) {
        return(identityRegistryAddress);
    }

    /**
    * @notice Set the EIN for the owner
    *
    * @param _newOwnerEIN The EIN for the new owner
    */
    function setOwnerEIN(uint _newOwnerEIN) public onlySnowflakeOwner {
        require(identityRegistryAddress != address(0), '1. The identity registry address is required');
        require(identityRegistry.identityExists(_newOwnerEIN), "New owner identity must exist");
        uint _callerEIN = identityRegistry.getEIN(msg.sender);
        require((ownerEIN == 0 || (_callerEIN == ownerEIN)), 'Owner must be zero or you must be the owner');
        if (ownerEIN == 0) {
            ownerEIN = _newOwnerEIN;
            emit OwnerWasSet(_newOwnerEIN);
        } else {
            uint _oldOwnerEIN = ownerEIN;
            ownerEIN = _newOwnerEIN;
            emit OwnershipTransferred(_oldOwnerEIN, _newOwnerEIN);
        }
    }

    /**
    * @notice Get EIN of the current owner
    * @dev This contracts allows you to set ownership based on EIN instead of address
    *
    * @return the address of the owner
    */
    function getOwnerEIN() public view returns(uint) {
        require(identityRegistryAddress != address(0), '3. The identity registry address is required');
        return ownerEIN;
    }

    /**
    * @notice Check if caller is owner
    * @dev This works on EINs, not on addresses
    *
    * @return true if `msg.sender` is the owner of the contract
    */
    function isEINowner() public view returns(bool) {
        require(identityRegistryAddress != address(0), '0. The identity registry address is required');
        uint caller = identityRegistry.getEIN(msg.sender);
        return (caller == ownerEIN);
    }

    /**
    * @notice Allows the current owner to relinquish control of the contract
    * @dev Renouncing to ownership will leave the contract without an owner. It will not be possible to call the functions which use the 'onlyOwner' modifier anymore
    */
    function renounceOwnership() public onlySnowflakeOwner {
        emit OwnershipTransferred(ownerEIN, 0);
        ownerEIN = 0;
    }

}
