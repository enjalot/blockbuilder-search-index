fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'

gh = require './github'

prune = (gist) ->
  pruned = {
    id: gist.id
    userId: gist.owner.login 
    description: gist.description
    created_at: gist.created_at
    updated_at: gist.updated_at
    files: gist.files
  }
  if gist.files["thumbnail.png"]
    pruned.thumbnail = gist.files["thumbnail.png"].raw_url
  return pruned

getPages = (username, gists, page, cb) ->
  #console.log "getting page #{page} for #{username}"
  gh.getUsersGists username, page, (err, response, body) ->
    newGists = parse(err, body)
    console.log("ERROR", err) if err
    #console.log "new gists", newGists
    return cb(gists) unless newGists && newGists.length > 0
    newGists.forEach (gist) ->
      # TODO: selectively pull files
      if gist.public && gist.files["index.html"] && !gist.files["_.md"] #cancel out tributary
        gists.push(prune(gist))
    setTimeout ->
      getPages username, gists, page+1, cb
    , 100


parse = (err, body) ->
  return null if err
  try
    return JSON.parse body
  catch e
    return null
  

getGistMetaData = ->
  usersString = fs.readFileSync('data/usables.csv').toString()
  users = d3.csv.parse usersString
  allGists = []
  async.eachLimit users, 5, (user, userCb) ->
    getPages user.username, [], 1, (gists) ->
      console.log "done with #{user.username}, found #{gists.length} gists"
      gists.forEach (g) ->
        allGists.push g
      userCb()
  , (results) ->
    console.log "done"
    console.log "all gists", allGists.length
    newGists = combine allGists
    fs.writeFileSync "data/gist-meta.json", JSON.stringify(newGists)
    #results.forEach (user) ->
    #  console.log user.login, user.public_gists

combine = (newGists) ->
  blocksList = JSON.parse(fs.readFileSync("data/gist-meta.json").toString() || "[]")
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


username = process.argv[2]
if username
  console.log "username", username
  getPages username, [], 1, (gists) ->
    gists.forEach (g) ->
      console.log g.id, g.description
    newGists = combine gists
    fs.writeFileSync "data/gist-meta.json", JSON.stringify(newGists)
else
  getGistMetaData()

###
gh.getUsersGists "sxywu", 3, (err, response, body) ->
  #console.log "RESPONSE", response.headers
  gists = parse(err, body)
  console.log "gists", gists?.length
###

###
getPages "sxywu", [], 1, (gists) ->
  console.log "sxywu GISTS", JSON.stringify gists, null, 2
###

###
getPages "biovisualize", [], 1, (gists) ->
  console.log "biovisualize GISTS", gists.length
###
