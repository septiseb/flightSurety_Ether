pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        string flight;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    struct AirlineQueue {
        uint256 votes;
        bool paid;
        bool accepted;
    }
    mapping(address => AirlineQueue) private airlines;

    bytes32[] registeredFlights;
    // instance of Data contract
    FlightSurityData data;
    // check if consensus is required for airlines - defaults to false
    bool private consensus;

    ////////////////////////////////////// EVENTS ////////////////////////////////////

    event FlightAdded(address airline, string flight, uint256 timestamp, bytes32 key);

 
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
            // Modify to call data contract's status
            require(isOperational(), "Contract is currently not operational");  
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

    modifier requireAirline()
        {
            require(data.isAirline(msg.sender));
            _;
        }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (address dataContract)
        public 
        {
            contractOwner = msg.sender;
            data = FlightSurityData(dataContract);
        }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational () 
        public
        view
        returns(bool) 
        {
            return data.isOperational();  // Modify to call data contract's status
        }

    function returnFlightsLength ()
        public
        view
        returns(uint) 
        {
            return registeredFlights.length;
        }

    function returnAirlineCount ()
        public
        view
        returns(uint) 
        {
            return data.countAirlines();
        }

    function returnFlightStatus (bytes32 key)
        public
        view
        returns(uint8) 
        {
            return flights[key].statusCode;
        }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline (address newAirline)
        external
        requireIsOperational
        requireAirline
        {
            uint256 count = data.countAirlines();
            if (count >= 4) {
                airlines[newAirline].votes++;
                if (airlines[newAirline].votes >= count.div(2)) {
                    airlines[newAirline].accepted = true;
                    if (airlines[newAirline].paid) {
                        data.registerAirline(newAirline);
                    }
                } 

            } else {
                airlines[newAirline].votes = 0;
                airlines[newAirline].accepted = true;
                if (airlines[newAirline].paid) {
                    data.registerAirline(newAirline);
                }
            }
        }

   /**
    * @dev Pay for an airline in the registration queue
    *
    */  
    function payAirlineFee (address newAirline)
        external
        payable
        requireIsOperational
        {
            require(msg.value >= 10 ether, "Value must be at least 10 ETH.");
            data.fund.value(msg.value)();
            airlines[newAirline].paid = true;

            if (airlines[newAirline].accepted) {
                data.registerAirline(newAirline);
            }
        }

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight (string flight, uint256 timestamp)
        external
        requireAirline
        requireIsOperational
        {
            bytes32 key = getFlightKey(msg.sender, flight, timestamp);
            flights[key].isRegistered = true;
            flights[key].flight = flight;
            flights[key].updatedTimestamp = timestamp;
            flights[key].airline = msg.sender;
            flights[key].statusCode = STATUS_CODE_UNKNOWN;
            registeredFlights.push(key);

            emit FlightAdded(msg.sender, flight, timestamp, key);
        }

    /**
    * @dev Return flight registered at 'i' index of registeredFlights[]
    *
    */
    function getFlight (uint i) 
        external
        view
        returns (bytes32, string, address, uint8) 
        {
            bytes32 key = registeredFlights[i];
            return(key, flights[key].flight, flights[key].airline, flights[key].statusCode);
        }

    /**
    * @dev Register a future flight for insuring.
    *
    */  
    function buy (bytes32 key)
        external
        payable
        requireIsOperational
        {
            require(msg.value <= 1 ether, "1 ETH is the max amount allowed.");
            string memory flight = flights[key].flight;
            data.buy.value(msg.value)(key, flight, msg.sender, msg.value);
        }

    /**
    * @dev Pull funds from data and send them to the passenger
    *
    */  
    function withdraw ()
        external
        requireIsOperational
        returns(uint256 credit)
        {
            // Check that the sender is the owner of the policy
            require(msg.sender == data.isCustomer(msg.sender));
            credit = data.withdraw(msg.sender);
            if (credit > 0) {
                emit Withdrawal(credit, msg.sender);
            }
            return credit;
        }
    
    event StatusUpdate(uint8 statusCode);

   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
        (
            address airline,
            string memory flight,
            uint256 timestamp,
            uint8 statusCode
        )
        internal
        requireIsOperational
        {
            bytes32 key = getFlightKey(airline, flight, timestamp);

            flights[key].statusCode = statusCode;
            if ((statusCode >= 20) && (statusCode <= 50)) {
                data.creditInsurees(key);
            }
         
            emit StatusUpdate(statusCode);
        }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
        (
            address airline,
            string flight,
            uint256 timestamp                            
        )
        external
        {
            uint8 index = getRandomIndex(msg.sender);

            // Generate a unique key for storing the request
            bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
            oracleResponses[key] = ResponseInfo(
                {
                    requester: msg.sender,
                    isOpen: true
                });

            emit OracleRequest(index, airline, flight, timestamp);
        } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    event Withdrawal(uint256 credit, address customer);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle ()
        external
        payable
        {
            // Require registration fee
            require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

            uint8[3] memory indexes = generateIndexes(msg.sender);

            oracles[msg.sender] = Oracle({
                isRegistered: true,
                indexes: indexes
            });
        }

    function getMyIndexes ()
        view
        external
        returns(uint8[3])
        {
            require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

            return oracles[msg.sender].indexes;
        }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
        (
            uint8 index,
            address airline,
            string flight,
            uint256 timestamp,
            uint8 statusCode
        )
        external
        {
            require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


            bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
            require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

            oracleResponses[key].responses[statusCode].push(msg.sender);

            // Information isn't considered verified until at least MIN_RESPONSES
            // oracles respond with the *** same *** information
            emit OracleReport(airline, flight, timestamp, statusCode);
            if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

                emit FlightStatusInfo(airline, flight, timestamp, statusCode);

                // Handle flight status as appropriate
                processFlightStatus(airline, flight, timestamp, statusCode);
            }
        }


    function getFlightKey
        (
            address airline,
            string flight,
            uint256 timestamp
        )
        pure
        internal
        returns(bytes32) 
        {
            return keccak256(abi.encodePacked(airline, flight, timestamp));
        }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
        (                       
            address account         
        )
        internal
        returns(uint8[3])
        {
            uint8[3] memory indexes;
            indexes[0] = getRandomIndex(account);
            
            indexes[1] = indexes[0];
            while(indexes[1] == indexes[0]) {
                indexes[1] = getRandomIndex(account);
            }

            indexes[2] = indexes[1];
            while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
                indexes[2] = getRandomIndex(account);
            }

            return indexes;
        }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
        (
            address account
        )
        internal
        returns (uint8)
        {
            uint8 maxValue = 10;

            // Pseudo random number...the incrementing nonce adds variation
            uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

            if (nonce > 250) {
                nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
            }

            return random;
        }

// endregion

}   

contract FlightSurityData {
    function isOperational () public view returns(bool);
    function isAirline (address) public view returns(bool);
    function countAirlines () public view returns(uint);
    function fund () external payable;
    function registerAirline (address) external;
    function buy (bytes32, string, address, uint256) external payable;
    function isCustomer (address) view public returns(address);
    function withdraw (address) external returns(uint256);
    function creditInsurees (bytes32) external;
}