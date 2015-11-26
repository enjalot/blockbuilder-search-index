request = require 'request'
conf = require './config.js'

count = 0

ghUrl = (url) ->
  options = {
    url: url,
    qs: {
      'client_id': conf.github.clientId,
      'client_secret': conf.github.secret
    },
    headers: {
      'User-Agent': 'Block-Scan'
    }
  };
  return options;

getUser = (username, cb) ->
  count++
  url = "https://api.github.com/users/" + username
  request.get(ghUrl(url), cb);

getGist = (gistId, cb) ->
  count++
  url = "https://api.github.com/gists/" + gistId
  request.get(ghUrl(url), cb);

getUsersGists = (username, page, cb) ->
  count++
  #since = ""
  since = "&since=2015-10-01T00:00:00Z"
  url = "https://api.github.com/users/#{username}/gists?page=#{page}&per_page=100" + since
  request.get ghUrl(url), (err, response, body) ->
    console.log "x-ratelimit-remaining:", response.headers['x-ratelimit-remaining']
    cb err, response, body
  #console.log("request count", count)

module.exports = {
  ghUrl, getUser, getGist, getUsersGists, count
}