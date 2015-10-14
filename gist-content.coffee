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


gistMeta = JSON.parse fs.readFileSync('data/gist-meta.json').toString()
console.log gistMeta.length

apiHash = {}

async.eachLimit gistMeta, 100, (gist, gistCb) ->
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
    gist.api = gapiHash
    delete gist.files
    gistCb()
  ###
  file = gist.files["index.html"]
  #console.log "requesting", file.raw_url
  request.get file.raw_url, (err, response, body) ->
    #console.log err, response, body?.length
    apis = parse(body)
    console.log file.raw_url, apis.length
    apis.forEach (api) ->
      api = api.slice(0, api.length-1)
      apiHash[api] = 0 unless apiHash[api]
      apiHash[api]++
    gistCb()
  ###
, () ->
  console.log "done", apiHash
  fs.writeFileSync "data/apis.json", JSON.stringify(apiHash)
  fs.writeFileSync "data/blocks.json", JSON.stringify(gistMeta)


