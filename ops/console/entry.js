const eth = require("ethers");

const constants = require("./constants");
const utils = require("./utils");
const helpers = require("./helpers");
const consideration = require("./consideration");
const test = require("./test");

// Add stuff that we want easy access to the global object
for (const key of Object.keys(utils || {})) {
  global[key] = utils[key];
}

global.test = test;
global.helpers = helpers;

// Add consideration helper fns to the global scope
for (const method of Object.keys(consideration || {})) {
  global[method] = consideration[method];
}

// Add all ethers utils & constants to the global scope for easy access
Object.keys(eth.utils || {}).forEach((key) => {
  global[key] = eth.utils[key];
});
Object.keys(eth.constants || {}).forEach((key) => {
  global[key] = eth.constants[key];
});

// Save deployments to global scope
for (const key of Object.keys(constants.deployments || {})) {
  global[key] = constants.deployments[key];
}

console.log("");

// Save contract instances to global scope
for (const key of Object.keys(constants.contracts || {})) {
  console.log(
    `Loading ${key} contract deployed to ${constants.contracts[key].address}`
  );
  global[key] = constants.contracts[key];
}

console.log("");

// Save helper fns to global scope
for (const key of Object.getOwnPropertyNames(consideration || {})) {
  console.log(`Loading Consideration helper method: ${key}`);
  global[key] = consideration[key];
}

console.log("");
