
fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'



allBlocks = []

# we want an object for each file, with associated gist metadata
fileBlocks = []

# global cache of all api functions
apiHash = {}
# global collection of blocks for API data
apiBlocks = []

colorHash = {}
colorBlocks = []

# number of missing files
missing = 0

done = (err) ->
  console.log "done", apiHash
  console.log "skipped #{missing} missing files"
  fs.writeFileSync "data/apis.json", JSON.stringify(apiHash)
  fs.writeFileSync "data/colors.json", JSON.stringify(colorHash)
  fs.writeFileSync "data/blocks.json", JSON.stringify(allBlocks)
  fs.writeFileSync "data/blocks-api.json", JSON.stringify(apiBlocks)
  fs.writeFileSync "data/blocks-colors.json", JSON.stringify(colorBlocks)
  fs.writeFileSync "data/files-blocks.json", JSON.stringify(fileBlocks)
  console.log "err", err if err
  console.log "wrote #{apiBlocks.length} API blocks"
  console.log "wrote #{colorBlocks.length} Color blocks"
  console.log "wrote #{fileBlocks.length} Files blocks"
  console.log "wrote #{allBlocks.length} total blocks"

# read in the list of gist metadata
gistMeta = JSON.parse fs.readFileSync('data/gist-meta.json').toString()
console.log gistMeta.length

pruneApi = (gist) ->
  pruned = {
    id: gist.id
    userId: gist.owner.login 
    #userId: gist.userId
    description: gist.description
    created_at: gist.created_at
    updated_at: gist.updated_at
    api: gist.api
    #files: gist.files
  }
  if gist.files["thumbnail.png"]
    pruned.thumbnail = gist.files["thumbnail.png"].raw_url
  return pruned

pruneColors = (gist) ->
  pruned = {
    id: gist.id
    userId: gist.owner.login 
    #userId: gist.userId
    description: gist.description
    created_at: gist.created_at
    updated_at: gist.updated_at
    colors: gist.colors
  }
  if gist.files["thumbnail.png"]
    pruned.thumbnail = gist.files["thumbnail.png"].raw_url
  return pruned

pruneFiles = (gist) ->
  fileNames = Object.keys gist.files
  prunes = []
  fileNames.forEach (fileName) ->
    file = gist.files[fileName]
    pruned = {
      gistId: gist.id
      userId: gist.userId
      description: gist.description
      created_at: gist.created_at
      updated_at: gist.updated_at
      fileName: fileName,
      file: file
    }
    prunes.push pruned
  return prunes



parseD3Functions = (code) ->
  # we match d3.foo.bar( which will find plugins and unnoficial api functions 
  re = new RegExp(/d3\.[a-zA-Z0-9\.]*?\(/g)
  matches = code.match(re) or []
  return matches

parseApi = (code, gist, gapiHash) ->
  apis = parseD3Functions(code)
  apis.forEach (api) ->
    api = api.slice(0, api.length-1)
    apiHash[api] = 0 unless apiHash[api]
    apiHash[api]++
    gapiHash[api] = 0 unless gapiHash[api]
    gapiHash[api]++
  return apis.length


addColors = (code, re, gcolorHash) ->
  matches = code.match(re) or []
  matches.forEach (color) ->
    colorHash[color] = 0 unless colorHash[color]
    colorHash[color]++
    gcolorHash[color] = 0 unless gcolorHash[color]
    gcolorHash[color]++


parseColors = (code, gist, gcolorHash) ->
  hsl = /hsla?\(\s*(\d{1,3})\s*,\s*(\d{1,3}\%)\s*,\s*(\d{1,3}\%)\s*(?:\s*,\s*(\d+(?:\.\d+)?)\s*)?\)/g;
  hex = /#[a-fA-F0-9]{3,6}/g;
  #someone clever could combine these two
  rgb = /rgb\((\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})\)/g;
  rgba = /rgba\((\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})\)/g; 
  addColors code, hsl, gcolorHash 
  addColors code, hex, gcolorHash 
  addColors code, rgb, gcolorHash 
  addColors code, rgba, gcolorHash 

  return Object.keys(gcolorHash).length



gistParser = (gist, gistCb) ->
  #console.log "NOT RETURNING", gist.id, singleId
  fileNames = Object.keys gist.files
  # per-gist cache of api functions that we build up in place
  gapiHash = {}
  gcolorHash = {}
  folder = __dirname + "/" + "data/gists/" + gist.id
  fs.mkdir folder, ->

  # we make a simplified data object for each file
  filepruned = pruneFiles gist
  fileBlocks = fileBlocks.concat filepruned

  async.each fileNames, (fileName, fileCb) ->
    ext = path.extname(fileName)
    if ext in [".html", ".js", ".coffee", ".md", ".json", ".csv", ".tsv"]
      file = folder + "/" + fileName
      fs.readFile file, (err, data) ->
        return fileCb() unless data
        contents = data.toString()
        if ext in [".html", ".js", ".coffee"]
          numApis = parseApi contents, gist, gapiHash
          numColors = parseColors contents, gist, gcolorHash
          console.log gist.id, fileName, numApis, numColors
          return fileCb()
        else if ext in ['.tsv', '.csv']
          # pull out # of rows and # of columns
          return fileCb()
        else 
          console.log gist.id, fileName
          return fileCb()
    else    
      return fileCb()
  , () ->
    if Object.keys(gapiHash).length > 0
      gist.api = gapiHash
      apiBlocks.push pruneApi(gist)
    if Object.keys(gcolorHash).length > 0
      gist.colors = gcolorHash
      colorBlocks.push pruneColors(gist)
    #console.log "GAPI HASH", gapiHash
    #delete gist.files
    allBlocks.push gist
    return gistCb()

async.eachLimit gistMeta, 100, gistParser, done