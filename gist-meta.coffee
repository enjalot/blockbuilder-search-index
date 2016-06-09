fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
moment = require 'moment'

gh = require './github'

###
# get all gists for everyone
coffee gist-meta.coffee
# get all gists updated/created in last 20 minutes for everyone
coffee gist-meta.coffee latest.json 20min
# get all gists for the new users (found in data/new-usables.csv)
coffee gist-meta.coffee '' '' new-users
###

filename = process.argv[2] || "data/gist-meta.json"
since = process.argv[3] || ""  # "2015-10-01T00:00:00Z"
if since == "15min"
  since = moment().subtract(15, "minutes")
  .utc()
    .format("YYYY-MM-DDTHH:mm:ss[Z]")
if since == "20min"
  since = moment().subtract(20, "minutes")
  .utc()
    .format("YYYY-MM-DDTHH:mm:ss[Z]")

singleUsername = process.argv[4]

# we will log our progress in ES
elasticsearch = require('elasticsearch')
esConfig = require('./config.js').elasticsearch
client = new elasticsearch.Client esConfig

# recursively fetch result pages from the GitHub API
getPages = (userName, gists, page, since, cb) ->
  gh.getUsersGists userName, page, since, (err, response, body) ->
    newGists = parse(err, body)
    console.log("ERROR", err) if err
    #console.log "new gists", newGists
    return cb(gists) unless newGists && newGists.length > 0
    newGists.forEach (gist) ->
      if gist.public && gist.files["index.html"] && !gist.files["_.md"] #cancel out tributary
        #gists.push(prune(gist))
        gists.push(gist)
    setTimeout ->
      getPages userName, gists, page+1, since, cb
    , 100

# this is the engine of this script. We loop over all the users we have
# and get the meta-data from the GitHub API for their latest gists
# using the "since" date. If no date is specified it gets the blocks since the
# start of time
getGistMetaData = ->
  if singleUsername and singleUsername == "new-users"
    usables = __dirname + '/data/new-usables.csv'
  else
    usables = __dirname + '/data/usables.csv'

  console.log "reading users from ", usables

  usersString = fs.readFileSync(usables).toString()
  users = d3.csv.parse usersString
  newGists = []
  async.eachLimit users, 5, (user, userCb) ->
    getPages user.username, [], 1, since, (gists) ->
      console.log "done with #{user.username}, found #{gists.length} gists"
      gists.forEach (g) ->
        newGists.push g
      setTimeout ->
        userCb()
      , 50
  , (results) ->
    console.log "done. number of new gists:", newGists.length

    # we always save to gist-meta.json
    saveGistMeta(newGists)
    # we write our gists to the specified file name if its not gist-meta
    if filename != 'data/gist-meta.json'
      console.log "writing #{newGists.length} to #{filename}"
      fs.writeFileSync filename, JSON.stringify(newGists)

    # log to elastic search
    summary =
      script: "meta"
      numBlocks: newGists.length
      filename: filename
      since: since || new Date("1970-01-01")
      ranAt: new Date()
    client.index
      index: 'bbindexer'
      type: 'scripts'
      body: summary
    , (err, response) ->
      console.log "indexed"
      process.exit()

saveGistMeta = (newGists) ->
  try
    blocksList = JSON.parse(fs.readFileSync(__dirname + '/data/gist-meta.json').toString() || "[]")
  catch e
    blocksList = []
  allGists = combine(blocksList, newGists)
  console.log "writing #{allGists.length} blocks to data/gist-meta.json"
  fs.writeFileSync __dirname + '/data/gist-meta.json', JSON.stringify(allGists)
  return

# this function combines the new gist meta-data with what we may have already
# gotten before. This allows us to accumulate new blocks incrementally
combine = (oldGists, newGists) ->
  console.log "combining #{newGists.length} with #{oldGists.length} existing blocks"
  blocks = {}
  oldGists.forEach (block) ->
    blocks[block.id] = block

  newGists.forEach (gist) ->
    blocks[gist.id] = gist

  ids = Object.keys(blocks)
  newBlockList = []
  ids.forEach (id) ->
    newBlockList.push blocks[id]
  return newBlockList

parse = (err, body) ->
  return null if err
  try
    return JSON.parse body
  catch e
    return null

if require.main == module
  if singleUsername and singleUsername != "new-users"
    console.log "username", singleUsername
    getPages singleUsername, [], 1, since, (gists) ->
      gists.forEach (g) ->
        console.log g.id, g.description
      fs.writeFileSync filename, JSON.stringify(gists)
      # we always write to our gist-meta file
      saveGistMeta(gists)
  else
    getGistMetaData()
