fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'
shell = require 'shelljs'

# we will log our progress in ES
elasticsearch = require('elasticsearch')
esConfig = require('./config.js').elasticsearch
client = new elasticsearch.Client esConfig


base = __dirname + "/data/gists-files/"
timeouts = []

done = (err, pruned) ->
  console.log "done writing files"
  if timeouts.length
    console.log "timeouts", timeouts
  if singleId
    console.log "single id", singleId
    return
  if ids
    console.log "ids", ids
    return
  # log to elastic search
  summary =
    script: "content"
    timeouts: timeouts
    filename: metaFile
    ranAt: new Date()
  client.index
    index: 'bbindexer'
    type: 'scripts'
    body: summary
  , (err, response) ->
    console.log "indexed"
    process.exit()

gistFetcher = (gist, gistCb) ->
  return gistCb() if !gist
  return gistCb() if !gist.files
  return gistCb() if ids && (gist.id not in ids)
  return gistCb() if singleId && (gist.id != singleId)
  #console.log "NOT RETURNING", gist.id, singleId
  fileNames = Object.keys gist.files
  folder = base + gist.id
  fs.mkdir folder, ->
  async.each fileNames, (fileName, fileCb) ->
    ext = path.extname(fileName).toLowerCase()
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
        if err
          console.log "timeout", gist.id
          timeouts.push gist.id
          console.log filePath, err
        return fileCb() unless body
        #console.log "writing body", body
        fs.writeFile filePath, body, ->
          console.log gist.id, fileName
          setTimeout ->
            fileCb()
          , Math.random() * 150 + 150
    else
      fileCb()
  , () ->
    gistCb()


module.exports =
  gistFetcher: gistFetcher

if require.main == module
  #base = __dirname + "/data/gists-clones/"
  fs.mkdir base, ->

  # specify the file to load, will probably be data/latest.json for our cron job
  metaFile = process.argv[2] || 'data/gist-meta.json'
  # skip existing files (faster for huge dump, but we want to update latest files)
  skipExisting = process.argv[3] == "skip" ? true : false

  # optionally pass in a csv file or a single id to be downloaded
  param = process.argv[4]
  if param
    if param.indexOf(".csv") > 0
      # list of ids to parse
      ids = d3.csv.parse(fs.readFileSync(singleId).toString())
    else
      singleId = param
      console.log "doing content for single block", singleId

  gistMeta = JSON.parse fs.readFileSync(metaFile).toString()
  console.log "number of gists", gistMeta.length
  if singleId or ids
    async.each gistMeta, gistFetcher, done
  else
    async.eachLimit gistMeta, 10, gistFetcher, done
