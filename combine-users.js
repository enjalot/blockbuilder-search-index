/*
This script draws in potential user names from several different sources and
combines them into one list of unique usernames
*/

const d3 = require('d3');
const request = require('request');
const fs = require('fs');

const userHash = {};

let total = 0;

const parseBlockURL = function(url) {
  const parts = url.split('//bl.ocks.org/');
  if (!parts[1]) {
    return;
  }
  const parts2 = parts[1].split('/');
  if (parts2.length === 1) {
    return;
  }
  const username = parts2[0];
  if (parseInt(username).toString() === username) {
    return;
  }
  if (username.indexOf('#') >= 0) {
    return;
  }
  if (username === 'd') {
    return;
  }
  return username;
};

// STACK OVERFLOW ---------------------------------------------------------------
// https://numeracy.co/projects/3PM9W1edMyC
// pull usernames out of block links found on StackOverflow, h/t @sirwart
let blocksStr = fs
  .readFileSync('data/user-sources/bl.ocks.org-links.tsv')
  .toString();
const blocksLinks = d3.tsv.parse(blocksStr);
blocksLinks.forEach(function(d) {
  const username = parseBlockURL(d.url);
  return (userHash[username] = 1);
});

const blocksusers = Object.keys(userHash).length;
total = blocksusers;
console.log(`${blocksusers} users from blocks links in SO`);

// KNIGHT EXAMPLES --------------------------------------------------------------
// pull usernames out of block links from the knight d3 course, h/t @micahstubbs
// https://docs.google.com/spreadsheets/d/1ByK9bGUrC-VT9xmdnHmrFMXZ-mEapCY2J6OlS1kf4eU/edit#gid=737064445
blocksStr = fs
  .readFileSync('data/user-sources/knight-d3-blocks-links.csv')
  .toString();
const blocksLinks2 = d3.csv.parse(blocksStr);
blocksLinks2.forEach(function(d) {
  const username = parseBlockURL(d.url);
  return (userHash[username] = 1);
});
const blocksusers2 = Object.keys(userHash).length;
total += blocksusers2;
console.log(`${blocksusers2} users from blocks links in knight course`);

// BLOCKBUILDER USERS -----------------------------------------------------------
// collect the usernames found in a dump of the public github profiles stored in blockbuilder
const string = fs
  .readFileSync('data/user-sources/blockbuilder-users.json')
  .toString();
string.split('\n').forEach(function(userStr) {
  try {
    const user = JSON.parse(userStr);
    if (!(user != null ? user.login : undefined)) {
      return;
    }
    return (userHash[user.login] = 1);
  } catch (e) {}
});

const bbusers = Object.keys(userHash).length - total;
total += bbusers;
console.log(`${bbusers} users added from bb`);

// MANUALLY CURATED USERS -------------------------------------------------------
// a list of manually currated users, h/t @d3visualization
const userscsv = fs
  .readFileSync('data/user-sources/manually-curated.csv')
  .toString();
d3.csv.parse(userscsv, function(user) {
  const username =
    user['username'] != null ? user['username'].toLowerCase() : undefined;
  if (!username) {
    return;
  }
  return (userHash[username] = 1);
});

const csvusers = Object.keys(userHash).length - total;
total += csvusers;
console.log(`${csvusers} added from manual list of users`);

// BL.OCKSPLORER FORM SUBMISSIONS ------------------------------------------------
// pull from the Google form provided by @ireneros @bocoup for blockscanner & http://bl.ocksplorer.org/
// https://docs.google.com/forms/d/1VdDdycNuqJVw3Ik6-ZLj6v7X9g2vWlw_RCC3RCfD9-I/viewform
const userDoc =
  'https://docs.google.com/spreadsheet/pub?key=0Al5UYaVoRpW3dE12bzRTVEp2RlJDQXdUYUFmODNiTHc&single=true&gid=0&output=csv';
const column =
  'Provide a github username to the person whose blocks (gists) we should scan for d3 API usage';
request.get(userDoc, function(err, response, body) {
  d3.csv.parse(body, function(user) {
    const username =
      user[column] != null ? user[column].toLowerCase() : undefined;
    if (!username) {
      return;
    }
    return (userHash[username] = 1);
  });

  let usernames = Object.keys(userHash);
  console.log(`${usernames.length - total} users added from blocksplorer`);
  total += usernames.length - total;
  console.log(`${usernames.length} users total`);
  usernames = usernames.sort();

  const users = `username\n${usernames.join('\n')}`;

  return fs.writeFileSync('data/users-combined.csv', users);
});
