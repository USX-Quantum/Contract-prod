// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBEP20 {
  
  function totalSupply() external view returns (uint256);
  
  function decimals() external view returns (uint8);
  
  function symbol() external view returns (string memory);
  
  function name() external view returns (string memory);
  
  function getOwner() external view returns (address);
  
  function balanceOf(address account) external view returns (uint256);
  
  function transfer(address recipient, uint256 amount) external returns (bool);
  
  function allowance(address _owner, address spender) external view returns (uint256);
  
  function approve(address spender, uint256 amount) external returns (bool);
  
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract USXVestingTimelock {

  IBEP20 _token;
  mapping(address => uint256) _beneficiaries;
  address[] _beneficiaryArray;

  address private _owner;

  uint256 _contractCreationDate;
  uint256 _vestPeriodSeconds;
  uint256 _numberOfVests;

  bool _releasingTokens;

  mapping(uint256 => uint256) _vestReleases;

  event ReleasedTokens(
    IBEP20 tokenAddress,
    address to,
    uint256 amount
  );

  constructor(
    uint256 vestPeriodSeconds,
    uint256 numberOfVests,
    IBEP20 tokenAddress
  ) {    
      _owner = msg.sender;
      _token = tokenAddress;
      _contractCreationDate = block.timestamp;
      // Vesting contract specific variables
      _numberOfVests = numberOfVests;
      _vestPeriodSeconds = vestPeriodSeconds;
  }
    
  modifier onlyOwner() {
      require(_owner == msg.sender, "Caller is not the owner");
      _;
  }

  function setBeneficiary(address beneficiary, uint256 amount) external onlyOwner {
    require(beneficiary != address(0), "VestingWallet: beneficiary is zero address");
    _beneficiaryArray.push(beneficiary);
    _beneficiaries[beneficiary] = amount;
    
  }
  
  function getBeneficiary(address beneficiary) public view returns(uint256){
    return _beneficiaries[beneficiary];
  }

  function getToken() external view returns(IBEP20) {
    return _token;
  }

  function beneficiaryLockedTokens(address beneficiary) external view returns(uint256) {
    return _token.balanceOf(beneficiary);
  }

  function lockedTokens() external view returns(uint256) {
    return _token.balanceOf(address(this));
  }

  function getVestReleasedOn(uint256 vestNumber) external view returns(uint256) {
    return _vestReleases[vestNumber];
  }

  function getFinalVestReleaseDate() external view returns(uint256) {
    return _contractCreationDate + (_numberOfVests * _vestPeriodSeconds);
  }

  function vestTimeLeft(uint256 vestNumber) external view returns(uint256) {
    uint256 vestReleaseTime = _getVestReleaseDate(vestNumber);

    if(block.timestamp < vestReleaseTime)
      return vestReleaseTime - block.timestamp;

    return 0;
  }

  function vestLockStatus(uint256 vestNumber) external view returns(bool) {
    return block.timestamp >= _getVestReleaseDate(vestNumber);
  }

  function blockTime() external view returns(uint256) {
    return block.timestamp;
  }

  function releaseVest(uint256 vestNumber) external onlyOwner returns(bool) {
    require(block.timestamp > _getVestReleaseDate(vestNumber), "VESTING: locktime has not run out yet.");
    require(_vestReleases[vestNumber] == 0, "VESTING: vest already released.");
    require(_releasingTokens == false, "VESTING: vest release in progress...");

    _releasingTokens = true;

    uint256 contractBalance = _token.balanceOf(address(this));

    require(contractBalance > 0, "VESTING: balance of contract is 0.");

    // Capture the vest release time before the transfer to prevent exploits
    uint256 captureTime = block.timestamp;

    // Transfer and emit event
    // This needs to be a loop over the mapping
    for (uint i=0; i<_beneficiaryArray.length; i++) {
      uint256 amount = _getTokenAmountPerVest(_beneficiaryArray[i]);
      _token.transfer(_beneficiaryArray[i], amount);
      emit ReleasedTokens(_token, _beneficiaryArray[i], amount);
      _beneficiaries[_beneficiaryArray[i]] = _beneficiaries[_beneficiaryArray[i]] - amount;
    }

    _vestReleases[vestNumber] = captureTime;
    _releasingTokens = false;
    
    return true;
  }
  
  // Wrapping internal functions
  function getVestReleaseDate(uint256 vestNumber) external view returns(uint256) {
    return _getVestReleaseDate(vestNumber);
  }

  // Wrapping internal functions
  function getTokenAmountPerVest(address beneficiary) external view returns(uint256) {
    return _getTokenAmountPerVest(beneficiary);
  }

  // Wrapping internal functions
  function numberOfVestsLeft() external view returns(uint256) {
    return _numberOfVestsLeft();
  }

  // Internal - Returns release date of a specific vest
  function _getVestReleaseDate(uint256 vestNumber) internal view returns (uint256) { 
    return _contractCreationDate + (_vestPeriodSeconds * vestNumber);
  }

  // Internal - returns number of tokens to be released per vest
  function _getTokenAmountPerVest(address beneficiary) internal view returns (uint256) {
    uint256 amount = _beneficiaries[beneficiary];
    uint256 vestsLeft = _numberOfVestsLeft();
    
    if (vestsLeft == 0)
      vestsLeft = 1;

    return amount / vestsLeft;
  }

  // Internal - returns number of vests yet to be withdrawn
  function _numberOfVestsLeft() internal view returns (uint256) {
    uint256 vestsLeft = 0;  

    for(uint256 i = 1; i <= _numberOfVests; i++) {
      if(_vestReleases[i] == 0) vestsLeft = vestsLeft + 1;
    }

    return vestsLeft;
  }
}
