pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                               // Account used to deploy contract
    bool private operational;                                    // Blocks all state changes throughout the contract if false
    uint private storedFunds;

    uint256 public airlineCount;

    mapping(address => bool) private confAirline;

    struct Policy {
        bytes32 key;
        string flight;
        uint256 amount;
        address owner;
        uint256 credit;
    }
    mapping(address => Policy) private policies;

    mapping(bytes32 => bool) private credits;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor (address firstAirline)
        public
        {
            contractOwner = msg.sender;
            operational = true;
            confAirline[firstAirline] = true;
            airlineCount++;
            storedFunds = 0;
        }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
        {
            require(operational, "Contract is currently not operational");
            _;  // All modifiers require an "_" which indicates where the function body will be added
        }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
        {
            require(msg.sender == contractOwner, "Caller is not contract owner");
            _;
        }
        /**
    * @dev Modifier that requires the flight key to have been credited from Oracle review
    */
    modifier requireCredit(address _address) 
        {
            bytes32 key = policies[_address].key;
            require(credits[key] == true, "There is no credit for this flight on this account");
            _;
        }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational () 
        public 
        view 
        returns(bool) 
        {
            return operational;
        }
 
    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode)
        external
        requireContractOwner 
        {
            operational = mode;
        }

    function countAirlines() public view returns (uint) 
        {
            return airlineCount;
        }
    
    function isAirline(address _address) view public returns (bool) 
        {   
            bool check = confAirline[_address];
            return check;
        }

    function isCustomer(address _address) view public returns (address) 
        {   
            address check = policies[_address].owner;
            return check;
        }

    function checkFunds() public view returns (uint) 
        {
            return storedFunds;
        }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline (address newAirline)
        external
        requireIsOperational
        {
            confAirline[newAirline] = true;
            airlineCount++;
        }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy (bytes32 _key, string _flight, address _owner, uint256 _amount)
        external
        payable
        requireIsOperational
        {
            policies[_owner].key = _key;
            policies[_owner].flight = _flight;
            policies[_owner].owner = _owner;
            policies[_owner].amount = _amount;
            storedFunds += msg.value;
        }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees (bytes32 key)
        external
        requireIsOperational
        {
            credits[key] = true;
        }

    /**
     *  @dev Pays insurees for loss
    */
    function withdraw (address passenger)
        external
        requireIsOperational
        requireCredit(passenger)
        returns(uint256 credited)
        {
            require(policies[passenger].owner == passenger);
            require(policies[passenger].amount > 0, "You don't currently have a policy.");
            uint256 deposit = policies[passenger].amount;
            uint256 credit = deposit.mul(3).div(2);
            require(storedFunds >= credit);
            policies[passenger].amount = 0;
            passenger.transfer(credit);
            return credited = credit;
        }
        

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund ()
        public
        payable
        requireIsOperational
        {
            storedFunds += msg.value;
        }

    function getFlightKey
        (
            address airline,
            string memory flight,
            uint256 timestamp
        )
        pure
        internal
        returns(bytes32) 
        {
            return keccak256(abi.encodePacked(airline, flight, timestamp));
        }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
        external
        payable 
        {
            // I guess since we have to call this here, throw in some arbitrary 
            // address for the funder - in this case the contract owner.
            fund();
        }


}
