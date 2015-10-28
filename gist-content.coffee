fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'

parse = (code) ->
  re = new RegExp(/d3\.[a-zA-Z0-9\.]*?\(/g)
  matches = code.match(re) or []
  return matches
  ###
  d3Functions.forEach(function(api) {
    var re = new RegExp(api, 'g')
    var matches = content.match(re)
    if(matches && matches.length) {
      existing.push({name: api, count: matches.length});
    }
  }); 
  ###

param = process.argv[2]
if param
  if param.indexOf(".csv") > 0
    # list of ids to parse
    ids = d3.csv.parse(fs.readFileSync(singleId).toString())
  else
    singleId = param
    console.log "doing meta for single block", singleId

gistMeta = JSON.parse fs.readFileSync('data/gist-meta.json').toString()
console.log gistMeta.length


combine = (newGists) ->
  blocksList = JSON.parse(fs.readFileSync("data/gist-content.json").toString() || "[]")
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


apiHash = {}



done = () ->
  console.log "done", apiHash
  if singleId
    console.log "single id", singleId
    return
  if ids
    console.log "ids", ids
    return
  fs.writeFileSync "data/apis.json", JSON.stringify(apiHash)
  fs.writeFileSync "data/blocks.json", JSON.stringify(gistMeta)

gistParser = (gist, gistCb) ->
  return gistCb() if ids && (gist.id not in ids)
  return gistCb() if singleId && (gist.id != singleId)
  #console.log "NOT RETURNING", gist.id, singleId
  fileNames = Object.keys gist.files
  gapiHash = {}
  async.each fileNames, (fileName, fileCb) ->
    if path.extname(fileName) in [".html", ".js"]
      file = gist.files[fileName]
      request.get file.raw_url, (err, response, body) ->
        #console.log err, response, body?.length
        return fileCb() unless body
        apis = parse(body)
        console.log file.raw_url, apis.length
        apis.forEach (api) ->
          api = api.slice(0, api.length-1)
          apiHash[api] = 0 unless apiHash[api]
          apiHash[api]++
          gapiHash[api] = 0 unless gapiHash[api]
          gapiHash[api]++
        fileCb()
    else
      fileCb()
  , () ->
    if !gist.api || Object.keys(gapiHash).length > 0
      gist.api = gapiHash
    #console.log "GAPI HASH", gapiHash
    delete gist.files
    gistCb()
  

if singleId or ids
  async.each gistMeta, gistParser, done
else
  async.eachLimit gistMeta, 100, gistParser, done