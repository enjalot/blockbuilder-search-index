const moment = require('moment');
const request = require('request');
const conf = require('./config.js');

module.exports = {
  processSince, getPages
}

function processSince(since) {
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
  return since
}

/*
from github.js
*/
function ghUrl(url) {
  const options = {
    url,
    qs: {
      client_id: conf.github.clientId,
      client_secret: conf.github.secret
    },
    headers: {
      'User-Agent': 'Block-Scan'
    }
  };
  return options;
};
function getUsersGists(username, page, since, cb) {
  let qsince;
  // count++;
  if (since) {
    qsince = `&since=${since}`;
  } else {
    qsince = '';
  }
  const url =
    `https://api.github.com/users/${username}/gists?page=${page}&per_page=100` +
    qsince;
  return request.get(ghUrl(url), function(err, response, body) {
    // TODO: handle errors more consistently
    if (err) {
      console.log(err);
    }
    console.log(
      'x-ratelimit-remaining:',
      response.headers['x-ratelimit-remaining']
    );
    return cb(err, response, body);
  });
};
// recursively fetch result pages from the GitHub API
function getPages (userName, gists, page, since, cb) {
  getUsersGists(userName, page, since, function(err, response, body) {
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
};


function parse(err, body) {
  if (err) { return null; }
  try {
    return JSON.parse(body);
  } catch (e) {
    return null;
  }
};
