
fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'

parse = require './parse.coffee'

elasticsearch = require('elasticsearch')
esConfig = require('./config.js').elasticsearch
client = new elasticsearch.Client {
  host: esConfig.host,
  #log: 'trace'
}

# number of missing files
missing = 0

# we may want to check if a document is in ES before trying to write it
# this can help us avoid overloading the server with writes when reindexing
skip = false
offset = 0

done = (err) ->
  console.log "done"
  console.log "skipped #{missing} missing files"
  console.log "err", err if err
  process.exit()


pruneES = (gist) ->
  # the JSON we will be sending to elasticsearch
  pruned = {
    userId: gist.owner?.login || "anonymous"
    description: gist.description
    created_at: gist.created_at
    updated_at: gist.updated_at
    api: Object.keys(gist.api || {})
    d3version: gist.d3version
    d3modules: Object.keys(gist.d3modules || {})
    colors: Object.keys(gist.colors || {})
    #tags: gist.tags || []
    #files:
    readme: gist.readme || ""
    code: gist.code || ""
    filenames: Object.keys(gist.files)
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
i = 0
gistParser = (gist, gistCb) ->
  #console.log "NOT RETURNING", gist.id, singleId
  #console.log "gist", gist.id
  i += 1
  index = i + 0
  return setImmediate(gistCb) if not gist?.files
  return setImmediate(gistCb) if not gist?.owner
  fileNames = Object.keys gist.files
  # per-gist cache of api functions that we build up in place
  gapiHash = {}
  gcolorHash = {}
  gmoduleHash = {}
  #folder = __dirname + "/" + "data/gists-files/" + gist.id
  folder = __dirname + "/data/gists-clones/#{gist.owner.login}/#{gist.id}"

  async.each fileNames, (fileName, fileCb) ->
    ext = path.extname(fileName).toLowerCase()
    if ext in [".html", ".js", ".coffee", ".md", ".json", ".csv", ".tsv", ".css"]
      file = folder + "/" + fileName
      fs.readFile file, (err, data) ->
        return fileCb() unless data
        contents = data.toString()
        # save the string back on the file
        gist.files[fileName].content = contents
        if fileName.toLowerCase() == "index.html"
          gist.d3version = parse.d3version(contents)
          parse.d3modules(contents, gmoduleHash)
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
      return setImmediate(fileCb)
  , () ->
    if Object.keys(gapiHash).length > 0
      gist.api = gapiHash

    if Object.keys(gcolorHash).length > 0
      gist.colors = gcolorHash

    if Object.keys(gmoduleHash).length > 0
      gist.d3modules = gmoduleHash

    if gist.files["thumbnail.png"]
      gist.thumbnail = gist.files["thumbnail.png"].raw_url
    if gist.files["preview.png"]
      gist.thumbnail = gist.files["preview.png"].raw_url

    # TODO make this more robust
    if gist.files["README.md"]
      gist.readme = gist.files["README.md"].content
    if gist.files["readme.md"]
      gist.readme = gist.files["readme.md"].content

    # for now we will just index
    if gist.files["index.html"]
      gist.code = gist.files["index.html"].content

    return gistCb() if !gist.owner

    return gistCb() if (gist.description and gist.description.indexOf("[UNLISTED]") >= 0 )

    es = pruneES(gist)

    
    #console.log "ES", JSON.stringify(es)

    if skip
      client.get
        index: 'blockbuilder'
        type: 'blocks'
        id: gist.id
      , (err) ->
        if err
          # post to elastic search, we don't have it indexed yet
          client.index
            index: 'blockbuilder'
            type: 'blocks'
            id: gist.id
            body: es
          , (err) ->
            console.log "indexed~", offset+index, gist.id
            return gistCb(err)
        else
          console.log "already", offset+index, gist.id
          setTimeout ->
            return gistCb()
          , Math.random() * 50 + 50
    else
      # post to elastic search
      client.index
        index: 'blockbuilder'
        type: 'blocks'
        id: gist.id
        body: es
      , (err) ->
        console.log "indexed", offset+index, gist.id
        setTimeout ->
          return gistCb(err)
        , Math.random() * 50 + 50

deleteGist = (gistId, gistCb) ->
  client.delete
    index: 'blockbuilder'
    type: 'blocks'
    id: gistId
  , (err, response) ->
    console.log "deleted", gistId
    return gistCb(err, response)

module.exports =
  gistParser: gistParser
  deleteGist: deleteGist
  prune: pruneES

if require.main == module
  # specify the file to load, will probably be data/latest.json for our cron job
  metaFile = process.argv[2] || __dirname + '/data/gist-meta.json'
  skip = true if process.argv[3] == "skip"
  offset = +process.argv[4] or 0

  # read in the list of gist metadata
  gistMeta = JSON.parse fs.readFileSync(metaFile).toString()
  console.log gistMeta.length, "gists"

  # I started running into request timeouts and memory errors
  # when trying to do all 11k at once. I realized I could skip ones
  # already indexed by slicing the array past whats already been indexed
  # (gist-meta is an ordered array, new gists are appended to it)
  async.eachLimit gistMeta.slice(offset), 20, gistParser, done
  #async.eachLimit gistMeta, 20, gistParser, done
