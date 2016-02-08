fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'
shell = require 'shelljs'


skipExisting = true
#skipExisting = false
  
#base = __dirname + "/data/gists-clones/"
base = __dirname + "/data/gists-files/"

fs.mkdir base, -> # "data/gists", ->

param = process.argv[2]
if param
  if param.indexOf(".csv") > 0
    # list of ids to parse
    ids = d3.csv.parse(fs.readFileSync(singleId).toString())
  else
    singleId = param
    console.log "doing content for single block", singleId

gistMeta = JSON.parse fs.readFileSync('data/gist-meta.json').toString()
console.log gistMeta.length

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

gistCloner = (gist, gistCb) ->
  # I wanted to actually clone all the repositories but it seems to be less reliable.
  # we get rate limited if we use https:// git urls
  # and the ssh ones disconnect unexpectedly, probably some sort of rate limiting but it doesn't show in
  # curl https://api.github.com/rate_limit
  return gistCb() if ids && (gist.id not in ids)
  return gistCb() if singleId && (gist.id != singleId)
  token = require('./config.js').github.token
  console.log("token", token)
  folder = base + gist.id
  shell.cd(base)
  # TODO don't use token in clone url (git init; git pull with token)
  shell.exec 'git clone https://' + token + ' @gist.github.com/' + gist.id, (code, huh, message) ->
  #shell.exec 'git clone git@gist.github.com:' + gist.id, (code, huh, message) ->
    fs.lstat folder + "/.git", (err, stats) ->
      if err
        #console.log "err", err 
        # github timed out
        console.log "timeout", gist.id
        timeouts.push gist.id
        return gistCb()
      if stats.isDirectory()
        # we want to be able to pull recently modified gists
        return gistCb()
        ###
        console.log("exists, pulling", gist.id)
        shell.cd gist.id
        shell.exec 'git pull origin master', (code, huh, message) ->
          console.log("pulled", gist.id)
          return gistCb()
        ###
      else
        console.log "cloned", gist.id
        setTimeout ->
          gistCb()
        , 50 + Math.random() * 300


gistFetcher = (gist, gistCb) ->
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
  async.each gistMeta, gistFetcher, done
  #async.each gistMeta, gistCloner, done
else
  async.eachLimit gistMeta, 100, gistFetcher, done
  #async.eachLimit gistMeta, 10, gistCloner, done