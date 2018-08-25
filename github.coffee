request = require 'request'
conf = require './config.js'

count = 0

ghCredentialIndex = 0;
ghClient = conf.github.clientId
ghSecret = conf.github.secret

ghUrl = (url) ->
  options = {
    url: url,
    qs: {
      'client_id': ghClient
      'client_secret': ghSecret 
    },
    headers: {
      'User-Agent': 'Block-Scan' + ghCredentialIndex
    }
  };
  return options;

# wrap the users callback in a function that lets us
# change the github client id on the fly if we run out of rate limit
rateLimitRotate = (url, cb) ->
  return (err, response, body) ->
    remaining = response?.headers['x-ratelimit-remaining'] || 0
    console.log "rate limit remaining", remaining
    if remaining <= 1 && conf.github.apps && (ghCredentialIndex < conf.github.apps.length - 1)
      ghCredentialIndex += 1
      console.log "switching apps", ghCredentialIndex
      ghClient = conf.github.apps[ghCredentialIndex].clientId
      ghSecret = conf.github.apps[ghCredentialIndex].secret
      if remaining < 1
        #resubmit the request
        gurl = ghUrl(url.url)
        console.log("resubmitting", gurl)
        return request.get(url, cb)

    # otherwise callback with the response
    cb(err, response, body)

getUser = (username, cb) ->
  count++
  url = "https://api.github.com/users/" + username
  gurl = ghUrl(url)
  # request.get(ghUrl(url), cb);
  request.get(gurl, rateLimitRotate(gurl, cb))

getGist = (gistId, cb) ->
  count++
  url = "https://api.github.com/gists/" + gistId
  gurl = ghUrl(url)
  # request.get(ghUrl(url), cb);
  request.get(gurl, rateLimitRotate(gurl, cb))

getUsersGists = (username, page, since, cb) ->
  count++
  if since
    qsince = "&since=" + since
  else
    qsince = ""
  url = "https://api.github.com/users/#{username}/gists?page=#{page}&per_page=100" + qsince
  request.get ghUrl(url), (err, response, body) ->
    # TODO: handle errors more consistently
    console.log err if err
    console.log "x-ratelimit-remaining:", response.headers['x-ratelimit-remaining']
    cb err, response, body
  #console.log("request count", count)

checkRateLimit = () ->
  cb = (err, response, body) ->
    console.log(body)
  url = ghUrl("https://api.github.com/rate_limit")
  # request.get(url, cb)
  request.get(url, rateLimitRotate(url, cb))

module.exports = {
  ghUrl, getUser, getGist, getUsersGists, count, checkRateLimit
}

