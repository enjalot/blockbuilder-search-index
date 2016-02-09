
fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'

parse = require './parse.coffee'

elasticsearch = require('elasticsearch')
esConfig = require('./config.js').elasticsearch
client = new elasticsearch.Client esConfig


# specify the file to load, will probably be data/latest.json for our cron job
metaFile = process.argv[2] || 'data/gist-meta.json'

# read in the list of gist metadata
gistMeta = JSON.parse fs.readFileSync(metaFile).toString()
console.log gistMeta.length, "gists"

# number of missing files
missing = 0

done = (err) ->
  console.log "done"
  console.log "skipped #{missing} missing files"
  console.log "err", err if err
  

pruneES = (gist) ->
  # the JSON we will be sending to elasticsearch
  pruned = {
    userId: gist.owner.login 
    description: gist.description
    created_at: gist.created_at
    updated_at: gist.updated_at
    api: Object.keys(gist.api || {})
    colors: Object.keys(gist.colors || {})
    #tags: gist.tags || []
    readme: gist.readme || ""
  }

  thumb = gist.files["thumbnail.png"]?.raw_url
  if gist.files["thumbnail.png"]
    #pruned.thumbnail = gist.files["thumbnail.png"].raw_url
    split = thumb.split '/raw/'
    commit = split[1].split('/thumbnail.png')[0]
    pruned.thumb = commit
  preview = gist.files["preview.png"]?.raw_url
  if gist.files["preview.png"]
    split = preview.split '/raw/'
    commit = split[1].split('/preview.png')[0]
    pruned.preview = commit

  return pruned


processed = 0
gistParser = (gist, gistCb) ->
  #console.log "NOT RETURNING", gist.id, singleId
  fileNames = Object.keys gist.files
  # per-gist cache of api functions that we build up in place
  gapiHash = {}
  gcolorHash = {}
  folder = __dirname + "/" + "data/gists-files/" + gist.id
  fs.mkdir folder, ->

  async.each fileNames, (fileName, fileCb) ->
    ext = path.extname(fileName).toLowerCase()
    if ext in [".html", ".js", ".coffee", ".md", ".json", ".csv", ".tsv", ".css"]
      file = folder + "/" + fileName
      fs.readFile file, (err, data) ->
        return fileCb() unless data
        contents = data.toString()
        # save the string back on the file
        gist.files[fileName].content = contents
        if ext in [".html", ".js", ".coffee"]
          numApis = parse.api contents, gist, gapiHash
          numColors = parse.colors contents, gist, gcolorHash
          parse.colorScales gapiHash, gcolorHash
          #console.log gist.id, fileName, numApis, numColors
          return fileCb()
        else if ext in ['.md']
          # pull out "hashtags"
          # TODO: come up with a hashtag convention that doesn't get confused with
          # markdown and hash-urls
          ###
          hashtag = /^#[a-zA-Z].?[\s\,]/g;
          tags = contents.match(hashtag)
          if tags && tags.length
            console.log gist.id, "tags", tags 
            gist.tags = tags
          ###
          # TODO: pull out user @-mentions
          return fileCb()
        else if ext in ['.tsv', '.csv']
          # pull out # of rows and # of columns
          return fileCb()
        else if ext in ['.css']
          numColors = parse.colors contents, gist, gcolorHash
          #console.log gist.id, fileName, 0, numColors
          return fileCb()
        else 
          #console.log gist.id, fileName
          return fileCb()
    else    
      return fileCb()
  , () ->
    if Object.keys(gapiHash).length > 0
      gist.api = gapiHash

    if Object.keys(gcolorHash).length > 0
      gist.colors = gcolorHash

    if gist.files["thumbnail.png"]
      gist.thumbnail = gist.files["thumbnail.png"].raw_url
    if gist.files["README.md"]
      gist.readme = gist.files["README.md"].content

    es = pruneES(gist)
    #console.log "ES", JSON.stringify(es)

    # post to elastic search
    client.index
      index: 'blockbuilder'
      type: 'blocks'
      id: gist.id
      body: es
    , (err, response) ->
      console.log "indexed", gist.id
      return gistCb()
      process.exit()

async.eachLimit gistMeta, 100, gistParser, done