fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'

gh = require './github'

parse = (err, body) ->
  return null if err
  try
    return JSON.parse body
  catch e
    return null

username = process.argv[2]
if username
  gh.getUser username, (err, response, body) ->
    u = parse(err, body)
    console.log u.login, u.public_gists
else
  usersString = fs.readFileSync('data/users.csv').toString()
  users = d3.csv.parse usersString
  usables = []
  async.each users, (user, userCb) ->
    gh.getUser user.username, (err, response, body) ->
      u = parse(err, body)
      return userCb() unless u
      #console.log err, response, u
      if u.public_gists > 0
        usables.push u.login
      if u.public_gists == 0
        console.log "no gists", u.login
      userCb()
  , ->
    str = "username\n" + usables.join("\n")
    console.log "#{usables.length} have at least 1 gist"
    fs.writeFileSync "data/usables.csv", str