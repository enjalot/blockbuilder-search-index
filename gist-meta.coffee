fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
moment = require 'moment'

gh = require './github'

filename = process.argv[2] || "data/gist-meta.json"
since = process.argv[3] || ""  # "2015-10-01T00:00:00Z"
if since == "15min"
  since = moment().subtract(15, "minutes").format()#.format("YYYY-MM-DDTHH:mm:ssZ")
  console.log "SINCE", since
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
  usersString = fs.readFileSync('data/usables.csv').toString()
  users = d3.csv.parse usersString
  allGists = []
  async.eachLimit users, 5, (user, userCb) ->
    getPages user.username, [], 1, since, (gists) ->
      console.log "done with #{user.username}, found #{gists.length} gists"
      gists.forEach (g) ->
        allGists.push g
      userCb()
  , (results) ->
    console.log "done"
    console.log "all gists", allGists.length
    newGists = combine allGists
    fs.writeFileSync filename, JSON.stringify(newGists)

    # log to elastic search
    summary = 
      script: "meta"
      numBlocks: allGists.length
      filename: filename
      since: since || new Date("1970-01-01")
      ranAt: new Date()
    client.index
      index: 'bbindexer'
      type: 'scripts'
      body: summary
    , (err, response) ->
      console.log "indexed"

# this function combines the new gist meta-data with what we may have already
# gotten before. This allows us to accumulate new blocks incrementally
combine = (newGists) ->
  if filename == "data/latest.json"
    # for latest gists we don't want to accumulate from multiple runs
    blocksList = []
  else
    try
      blocksList = JSON.parse(fs.readFileSync(filename).toString() || "[]")
    catch e
      blocksList = []

  console.log "loaded #{blocksList.length} existing blocks"
  blocks = {}
  blocksList.forEach (block) ->
    blocks[block.id] = block

  newGists.forEach (gist) ->
    blocks[gist.id] = gist

  ids = Object.keys(blocks)
  console.log "now we have #{ids.length} blocks"
  newBlockList = []
  ids.forEach (id) ->
    newBlockList.push blocks[id]
  console.log "just to be sure #{newBlockList.length}"
  return newBlockList


parse = (err, body) ->
  return null if err
  try
    return JSON.parse body
  catch e
    return null

if singleUsername
  console.log "username", singleUsername
  getPages username, [], 1, since, (gists) ->
    gists.forEach (g) ->
      console.log g.id, g.description
    newGists = combine gists
    fs.writeFileSync filename, JSON.stringify(newGists)
else
  getGistMetaData()

