const fs = require('fs');
const d3 = require('d3');
const async = require('async');
const request = require('request');
const moment = require('moment');

const gh = require('./github');

//
// Usage
//

// get all gists for everyone
// $ node gist-meta.js

// get all gists updated/created in last 20 minutes for everyone
// $ node gist-meta.js latest.json 20min

// get all gists for the new users (found in data/new-usables.csv)
// $ node gist-meta.js '' '' new-users


const filename = process.argv[2] || "data/gist-meta.json";
let since = process.argv[3] || "";  // "2015-10-01T00:00:00Z"
if (since === "15min") {
  since = moment().subtract(15, "minutes")
  .utc()
    .format("YYYY-MM-DDTHH:mm:ss[Z]");
}
if (since === "20min") {
  since = moment().subtract(20, "minutes")
  .utc()
    .format("YYYY-MM-DDTHH:mm:ss[Z]");
}

const singleUsername = process.argv[4];

// we will log our progress in ES
const elasticsearch = require('elasticsearch');
const esConfig = require('./config.js').elasticsearch;
const client = new elasticsearch.Client(esConfig);

// recursively fetch result pages from the GitHub API
var getPages = (userName, gists, page, since, cb) =>
  gh.getUsersGists(userName, page, since, function(err, response, body) {
    const newGists = parse(err, body);
    if (err) { console.log("ERROR", err); }
    //console.log("new gists", newGists);
    if (!newGists || !(newGists.length > 0)) { return cb(gists); }
    newGists.forEach(function(gist) {
      if (gist.public && gist.files["index.html"] && !gist.files["_.md"]) { //cancel out tributary
        //gists.push(prune(gist));
        return gists.push(gist);
      }
    });
    return setTimeout(() => getPages(userName, gists, page+1, since, cb)
    , 100);
  })
;

// this is the engine of this script. We loop over all the users we have
// and get the meta-data from the GitHub API for their latest gists
// using the "since" date. If no date is specified it gets the blocks since the
// start of time
const getGistMetaData = function() {
  let usables;
  if (singleUsername && (singleUsername === "new-users")) {
    usables = __dirname + '/data/new-usables.csv';
  } else {
    usables = __dirname + '/data/usables.csv';
  }

  console.log("reading users from ", usables);

  const usersString = fs.readFileSync(usables).toString();
  const users = d3.csv.parse(usersString);
  const newGists = [];
  return async.eachLimit(users, 5, (user, userCb) =>
    getPages(user.username, [], 1, since, function(gists) {
      console.log(`done with ${user.username}, found ${gists.length} gists`);
      gists.forEach(g => newGists.push(g));
      return setTimeout(() => userCb()
      , 50);
    })
  
  , function(results) {
    console.log("done. number of new gists:", newGists.length);

    // we always save to gist-meta.json
    saveGistMeta(newGists);
    // we write our gists to the specified file name if its not gist-meta
    if (filename !== 'data/gist-meta.json') {
      console.log(`writing ${newGists.length} to ${filename}`);
      fs.writeFileSync(filename, JSON.stringify(newGists));
    }

    // log to elastic search
    const summary = {
      script: "meta",
      numBlocks: newGists.length,
      filename,
      since: since || new Date("1970-01-01"),
      ranAt: new Date()
    };
    return client.index({
      index: 'bbindexer',
      type: 'scripts',
      body: summary
    }
    , function(err, response) {
      console.log("indexed");
      return process.exit();
    });
  });
};

var saveGistMeta = function(newGists) {
  let blocksList;
  try {
    blocksList = JSON.parse(fs.readFileSync(__dirname + '/data/gist-meta.json').toString() || "[]");
  } catch (e) {
    blocksList = [];
  }
  const allGists = combine(blocksList, newGists);
  console.log(`writing ${allGists.length} blocks to data/gist-meta.json`);
  fs.writeFileSync(__dirname + '/data/gist-meta.json', JSON.stringify(allGists));
};

// this function combines the new gist meta-data with what we may have already
// gotten before. This allows us to accumulate new blocks incrementally
var combine = function(oldGists, newGists) {
  console.log(`combining ${newGists.length} with ${oldGists.length} existing blocks`);
  const blocks = {};
  oldGists.forEach(block => blocks[block.id] = block);

  newGists.forEach(gist => blocks[gist.id] = gist);

  const ids = Object.keys(blocks);
  const newBlockList = [];
  ids.forEach(id => newBlockList.push(blocks[id]));
  return newBlockList;
};

var parse = function(err, body) {
  if (err) { return null; }
  try {
    return JSON.parse(body);
  } catch (e) {
    return null;
  }
};

if (require.main === module) {
  if (singleUsername && (singleUsername !== "new-users")) {
    console.log("username", singleUsername);
    getPages(singleUsername, [], 1, since, function(gists) {
      gists.forEach(g => console.log(g.id, g.description));
      fs.writeFileSync(filename, JSON.stringify(gists));
      // we always write to our gist-meta file
      return saveGistMeta(gists);
    });
  } else {
    getGistMetaData();
  }
}
