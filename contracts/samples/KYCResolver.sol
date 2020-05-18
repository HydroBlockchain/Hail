pragma solidity ^0.5.0;


contract KYCResolver {


	mapping(uint256 => bool) public rejectedEin;


    constructor() public {
    }


    function isApproved(uint256 _ein, uint256 _amount) external view returns (bool) {
        require(_amount > 0);
        if (rejectedEin[_ein]) return false;
        return true;
    }


    function rejectEin(uint256 _ein) public {
    	rejectedEin[_ein] = true;
    }

    function approveEin(uint256 _ein) public {
        rejectedEin[_ein] = false;
    }

}
