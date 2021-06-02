import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import "babel-polyfill";

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

// Response cases
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;

let accounts = [];
let oracles = [];
let oracleResponse;

////////////////////////////////// REGISTER ORACLES ////////////////////////////////

async function registerOracles() {
    
  let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call({from: web3.eth.defaultAccount});
  accounts = await web3.eth.getAccounts();

  // Start with the 10th address and go to the 30th.  Leave the first 10 for airlines and passengers.
  for(let a=10; a<30; a++) {   
    let account = accounts[a];

    await flightSuretyApp.methods.registerOracle().send({
      from: account, 
      value: fee, 
      gas: 4712388
    });
    let result = await flightSuretyApp.methods.getMyIndexes().call({from: account});
    console.log(`Oracle Registered: ${account}, ${result[0]}, ${result[1]}, ${result[2]}, oracle count: ${oracles.length}`);
    oracles.push(account);
  }
}

/////////////////////////////// HANDLE ORACLE REQUEST /////////////////////////////

async function callOracles(index, airline, flight, timestamp) {

  // HARD-CODED RESPONSE - ONLY FOR TESTING
  // But I'll leave this one here so there's some proof-of-concept built in
  oracleResponse = STATUS_CODE_LATE_WEATHER;

  accounts = await web3.eth.getAccounts();

  // Start with the 10th address and go to the 30th.  Leave the first 10 for airlines and passengers.
  for(let b=0; b<oracles.length; b++) {   
    let oracle = oracles[b];
      try {
        await flightSuretyApp.methods.submitOracleResponse(
            index,
            airline,
            flight,
            timestamp,
            oracleResponse
        ).send({from: oracle, gas: 999999});
        console.log(`Oracle ${b} responded with ${oracleResponses} for flight ${flight}`)
      } catch(e) {console.log(e)}
  }
}
///////////////////////////////// LISTEN FOR EVENTS ///////////////////////////////

// Event emitted from Blockchain to signal Oracle response
flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, (err, res) => {
    if (err) {
      console.log(err);
    } else {
        callOracles(
          res.returnValues[0],
          res.returnValues[1],
          res.returnValues[2],
          res.returnValues[3],
        )
    }
});

// Check Oracle report for verification
flightSuretyApp.events.FlightAdded({
  fromBlock: 0
}, function (error, event) {
  if (error) {console.log(error)}
  console.log(event)
});

// Event emitted from blockchain notifying of a new flight being added
flightSuretyApp.events.FlightStatusInfo({
  fromBlock: 0
}, function (error, event) {
  if (error) {console.log(error)}
  console.log('Flight Status Info: ', event)
});

// Event emitted from blockchain showing update of flight status
flightSuretyApp.events.StatusUpdate({
  fromBlock: 0
}, function (error, event) {
  if (error) {console.log(error)}
  console.log('********* App Flight Status Update ********* ', event)
});

flightSuretyApp.events.Withdrawal({
  fromBlock: 0
}, function (error, event) {
  if (error) {console.log(error)}
  console.log('Withdrawal: ', event)
});

// Register Oracles on server startup
registerOracles();

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;