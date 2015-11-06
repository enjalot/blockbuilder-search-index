fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'


skipExisting = true
#skipExisting = false

prune = (gist) ->
  pruned = {
    id: gist.id
    #userId: gist.owner.login 
    userId: gist.userId
    description: gist.description
    created_at: gist.created_at
    updated_at: gist.updated_at
    api: gist.api
    #files: gist.files
  }
  if gist.files["thumbnail.png"]
    pruned.thumbnail = gist.files["thumbnail.png"].raw_url
  return pruned

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

fs.mkdir "data/gists", ->

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

parseApi = (body, gist, gapiHash, fileName, cb) ->
  apis = parse(body)
  apis.forEach (api) ->
    api = api.slice(0, api.length-1)
    apiHash[api] = 0 unless apiHash[api]
    apiHash[api]++
    gapiHash[api] = 0 unless gapiHash[api]
    gapiHash[api]++
  cb(apis.length)

done = (err, pruned) ->
  console.log "done writing files"
  #console.log "done", apiHash
  if singleId
    console.log "single id", singleId
    return
  if ids
    console.log "ids", ids
    return
  #fs.writeFileSync "data/apis.json", JSON.stringify(apiHash)
  #fs.writeFileSync "data/blocks.json", JSON.stringify(pruned)

gistParser = (gist, gistCb) ->
  return gistCb() if ids && (gist.id not in ids)
  return gistCb() if singleId && (gist.id != singleId)
  #console.log "NOT RETURNING", gist.id, singleId
  fileNames = Object.keys gist.files
  gapiHash = {}
  folder = "data/gists/" + gist.id
  fs.mkdir folder, ->
  async.each fileNames, (fileName, fileCb) ->
    ext = path.extname(fileName)
    filePath = folder + "/" + fileName
    if skipExisting
      try
        if fs.lstatSync(filePath)
          # if it exists we skip it
          console.log "skipping", gist.id, fileName
          return fileCb()
      catch e
        # otherwise we just continue
    if ext in [".html", ".js", ".coffee", ".md", ".json", ".csv", ".tsv"]
      file = gist.files[fileName]
      request.get file.raw_url, (err, response, body) ->
        #console.log err, response, body?.length
        console.log filePath, err if err
        return fileCb() unless body
        #console.log "writing body", body
        fs.writeFile filePath, body, ->
          ###
          if ext in [".html", ".js", ".coffee"]
            parseApi body, gist, gapiHash, fileName, (numApis) ->
              console.log gist.id, fileName, numApis
              fileCb()
          else
          ###
          console.log gist.id, fileName
          fileCb()
    else
      fileCb()
  , () ->
    if !gist.api || Object.keys(gapiHash).length > 0
      gist.api = gapiHash
    #console.log "GAPI HASH", gapiHash
    #delete gist.files
    gistCb(null, prune(gist))
  

if singleId or ids
  async.each gistMeta, gistParser, done
else
  async.eachLimit gistMeta, 100, gistParser, done