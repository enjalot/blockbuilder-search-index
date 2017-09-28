const request = require('request');
const conf = require('./config.js');

let count = 0;

const ghUrl = function(url) {
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

const getUser = function(username, cb) {
  count++;
  const url = `https://api.github.com/users/${username}`;
  return request.get(ghUrl(url), cb);
};

const getGist = function(gistId, cb) {
  count++;
  const url = `https://api.github.com/gists/${gistId}`;
  return request.get(ghUrl(url), cb);
};

const getUsersGists = function(username, page, since, cb) {
  let qsince;
  count++;
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
//console.log("request count", count)

module.exports = {
  ghUrl,
  getUser,
  getGist,
  getUsersGists,
  count
};
