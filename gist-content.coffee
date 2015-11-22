fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'


skipExisting = true
#skipExisting = false

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

done = (err, pruned) ->
  console.log "done writing files"
  #console.log "done", apiHash
  if singleId
    console.log "single id", singleId
    return
  if ids
    console.log "ids", ids
    return

gistParser = (gist, gistCb) ->
  return gistCb() if ids && (gist.id not in ids)
  return gistCb() if singleId && (gist.id != singleId)
  #console.log "NOT RETURNING", gist.id, singleId
  fileNames = Object.keys gist.files
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
    if ext in [".html", ".js", ".coffee", ".md", ".json", ".csv", ".tsv", ".css"]
      file = gist.files[fileName]
      request.get file.raw_url, (err, response, body) ->
        #console.log err, response, body?.length
        console.log filePath, err if err
        return fileCb() unless body
        #console.log "writing body", body
        fs.writeFile filePath, body, ->
          console.log gist.id, fileName
          fileCb()
    else
      fileCb()
  , () ->
    gistCb()
  

if singleId or ids
  async.each gistMeta, gistParser, done
else
  async.eachLimit gistMeta, 100, gistParser, done