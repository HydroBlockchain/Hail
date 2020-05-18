pragma solidity ^0.5.0;

import '../HSToken.sol';
import '../interfaces/IdentityRegistryInterfaceShort.sol';
import './HSTServiceRegistry.sol';
import './SnowflakeOwnable.sol';


/**
 * @title HSTokenRegistry
 * @notice Keep track of contracts for the issuance of Hydro Securities
 * @author Fatima Castiglione Maldonado <castiglionemaldonado@gmail.com>
 */
contract HSTokenRegistry is SnowflakeOwnable {

  struct TokenData {
    uint id;
    bytes32 tokenSymbol;
    bytes32 tokenName;
    uint ownerEIN;
    string tokenDescription;
    uint8 tokenDecimals;
    bool tokenHasLegalApproval;
    bool tokenExists;
  }

  struct SymbolData {
    uint256 id;
    bool symbolExists;
    address tokenAddress;
  }

  struct NameData {
    uint256 id;
    bool nameExists;
    address tokenAddress;
  }

  uint256 public lastID = 0;

  IdentityRegistryInterface public identityRegistry;
  HSTServiceRegistry public serviceRegistry;

  // Token address => Token data structure
  mapping(address => TokenData) public tokens;

  // Token symbol => Symbol data structure
  mapping(bytes32 => SymbolData) public symbols;

  // Token name => Name data structure
  mapping(bytes32 => NameData) public names;

  // Token owner EIN => exists
  mapping(uint => bool) public owners;

  event TokenAppointedToRegistry(
    address _tokenAddress,
    bytes32 _tokenSymbol,
    bytes32 _tokenName,
    uint256 _id
  );

  event TokenAlreadyExists(
    address _tokenAddress,
    string _description
  );

  event SymbolAlreadyExists(
    bytes32 _tokenSymbol,
    string _description
  );

  event NameAlreadyExists(
    bytes32 _tokenName,
    string _description
  );

  event TokenHasLegalApproval(
    address _tokenAddress,
    bytes32 _tokenSymbol,
    bytes32 _tokenName,
    uint _MainLegalAdvisorEIN
  );


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
    require(length > 0, "This is not a contract");
  }


  /**
  * @notice Set the address for the registries
  *
  * @param _identityRegistryAddress The address for the identity registry
  * @param _serviceRegistryAddress The address for the service registry
  */
  function setAddresses (
    address _identityRegistryAddress,
    address _serviceRegistryAddress)
    public
    isContract(_identityRegistryAddress)
    isContract(_serviceRegistryAddress)
  {
    identityRegistry = IdentityRegistryInterface(_identityRegistryAddress);
    serviceRegistry = HSTServiceRegistry(_serviceRegistryAddress);
  }


   /**
  * @notice Get a Hydro Securities Token contract deployed address
  * @param  _tokenSymbol The symbol of the token
  * @return the address of the token contract corresponding to that name
  */
  function getSecuritiesTokenAddressBySymbol(bytes32 _tokenSymbol) public view returns(address) {
    return symbols[_tokenSymbol].tokenAddress;
  }

  /**
  * @notice Get a Hydro Securities Token contract deployed address
  * @param  _tokenName The name of the token
  * @return the address of the token contract corresponding to that name
  */
  function getSecuritiesTokenAddressByName(bytes32 _tokenName) public view returns(address) {
    return names[_tokenName].tokenAddress;
  }

  /**
  * @notice Get last registered token ID
  * @return the last ID generated for a token
  */
  function getLastTokenID() public view returns(uint) {
    return lastID;
  }


  /**
  * @notice Appoint a new Token to the registry if token exists
  * @param  _tokenName The name of the token contract set to be deployed
  * @return true if token is created
  */
  function appointToken(
    address _tokenAddress,
    bytes32 _tokenSymbol,
    bytes32 _tokenName,
    string memory _tokenDescription,
    uint8 _tokenDecimals)
  public returns(bool) {
    require(_tokenAddress != address(0), 'Token address is required');
    require (_tokenSymbol.length != 0, "Token symbol cannot be blank");
    require (_tokenName.length != 0, "Token name cannot be blank");
    require (bytes(_tokenDescription).length != 0, "Token description cannot be blank");
    require (_tokenDecimals != 0, "Token decimals cannot be zero");

    HSToken _token;

    if ( tokens[_tokenAddress].tokenExists == true ) {
      emit TokenAlreadyExists(_tokenAddress, "Token already exists");
      return false;
    }

    if ( names[_tokenName].nameExists ) {
      _token = HSToken(names[_tokenName].tokenAddress);
      if ( _token.isTokenAlive() ) {
        emit NameAlreadyExists(_tokenName, "Token already exists and it is alive");
        return false;
      }
    }

    if ( symbols[_tokenSymbol].symbolExists ) {
      _token = HSToken(symbols[_tokenSymbol].tokenAddress);
      if ( _token.isTokenAlive() ) {
        emit SymbolAlreadyExists(_tokenSymbol, "Symbol already exists");
        return false;
      }
    }

    lastID++;

    uint _ownerEIN = identityRegistry.getEIN(msg.sender);

    tokens[_tokenAddress].id = lastID;
    tokens[_tokenAddress].tokenSymbol = _tokenSymbol;
    tokens[_tokenAddress].tokenName = _tokenName;
    tokens[_tokenAddress].ownerEIN = _ownerEIN;
    tokens[_tokenAddress].tokenDescription = _tokenDescription;
    tokens[_tokenAddress].tokenDecimals = _tokenDecimals;
    tokens[_tokenAddress].tokenHasLegalApproval = false;
    tokens[_tokenAddress].tokenExists = true;

    symbols[_tokenSymbol].id = lastID;
    symbols[_tokenSymbol].symbolExists = true;
    symbols[_tokenSymbol].tokenAddress = _tokenAddress;

    names[_tokenName].id = lastID;
    names[_tokenName].nameExists = true;
    names[_tokenName].tokenAddress = _tokenAddress;

    owners[_ownerEIN] = true;

    serviceRegistry.addDefaultCategories(_tokenAddress);

    emit TokenAppointedToRegistry(_tokenAddress,_tokenName, _tokenSymbol, lastID);

    return true;
  }

  /**
  * @notice Find out if token is registered
  * @param  _tokenAddress The address of the Token
  * @return true if the token is registered
  */
  function isRegisteredToken(address _tokenAddress) public view returns(bool) {
    return tokens[_tokenAddress].tokenExists;
  }

  /**
  * @notice Find out if owner is registered
  * @param  _ownerEIN The EIN of the Token owner
  * @return true if the owner is registered
  */
  function isRegisteredOwner(uint _ownerEIN) public view returns(bool) {
    return owners[_ownerEIN];
  }

  /**
  * @notice Get a Hydro Securities Token symbol
  * @param  _tokenAddress The address of the Token
  * @return the symbol of the Token
  */
  function getSecuritiesTokenSymbol(address _tokenAddress) public view returns(bytes32) {
    return tokens[_tokenAddress].tokenSymbol;
  }

  /**
  * @notice Get a Hydro Securities Token name
  * @param  _tokenAddress The name of the Token
  * @return the name of the Token
  */
  function getSecuritiesTokenName(address _tokenAddress) public view returns(bytes32) {
    return tokens[_tokenAddress].tokenName;
  }

 /**
  * @notice Get a Hydro Securities token owner EIN
  * @param  _tokenAddress The address of the token
  * @return the owner EIN of the token
  */
  function getSecuritiesTokenOwnerEIN(address _tokenAddress) public view returns(uint) {
    return tokens[_tokenAddress].ownerEIN;
  }

 /**
  * @notice Get a Hydro Securities token description
  * @param  _tokenAddress The address of the token
  * @return the description for the token]
  */
  function getSecuritiesTokenDescription(address _tokenAddress) public view returns(string memory) {
    return tokens[_tokenAddress].tokenDescription;
  }

 /**
  * @notice Get a Hydro Securities token decimals
  * @param  _tokenAddress The address of the token
  * @return the number of decimals for the token corresponding to that name
  */
  function getSecuritiesTokenDecimals(address _tokenAddress) public view returns(uint8) {
    return tokens[_tokenAddress].tokenDecimals;
  }

  /**
  * @notice Grant legal approval for a security token
  * @param  _tokenAddress The address of the Token
  * @return true if approval is granted
  */
  function grantLegalApproval(address _tokenAddress) public returns(bool) {
    // get caller EIN
    uint _callerEIN = identityRegistry.getEIN(msg.sender);
    // check that caller is the Legal Advisor for this token
    require(serviceRegistry.getService(_tokenAddress, _callerEIN) == "MLA",
      "Only main legal advisor can grant legal approval");
    // approve
    tokens[_tokenAddress].tokenHasLegalApproval = true;
    emit TokenHasLegalApproval(
      _tokenAddress,
      tokens[_tokenAddress].tokenSymbol,
      tokens[_tokenAddress].tokenName,
      _callerEIN
    );
    return true;
  }

  /**
  * @notice Get legal approval for a security token
  * @param  _tokenAddress The address of the Token
  * @return true if the token has legal approval
  */
  function checkLegalApproval(address _tokenAddress) public view returns(bool) {
    return tokens[_tokenAddress].tokenHasLegalApproval;
  }

}
