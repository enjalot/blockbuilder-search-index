
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


base = __dirname + "/data/gists-clones/"
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

gistCloner = (gist, gistCb) ->
  # I wanted to actually clone all the repositories but it seems to be less reliable.
  # we get rate limited if we use https:// git urls
  # and the ssh ones disconnect unexpectedly, probably some sort of rate limiting but it doesn't show in
  # curl https://api.github.com/rate_limit
  return gistCb() if ids && (gist.id not in ids)
  return gistCb() if singleId && (gist.id != singleId)
  token = require('./config.js').github.token
  #console.log("token", token)
  if gist.owner
    user = gist.owner.login
  else
    user = 'anonymous'

  userfolder = base + user
  folder = userfolder + '/' + gist.id
  try
    fs.mkdirSync userfolder
  catch e
    foo = null

  #shell.cd(userfolder)
  # TODO don't use token in clone url (git init; git pull with token)
  #fs.lstat folder + "/.git", (err, stats) ->
  fs.lstat folder, (err, stats) ->
    # TODO check for files?
    if stats && stats.isDirectory()
      console.log "already got", gist.id
      # we want to be able to pull recently modified gists
      cmd = "cd #{userfolder}/#{gist.id}; git pull origin master"
      shell.exec cmd, (code, huh, message) ->
        if code or message
          console.log gist.id, user, code, message
        else
          console.log "pulled #{gist.id} into #{user}'s folder'"
        setTimeout ->
          return gistCb()
        , 250 + Math.random() * 500
    else
      if(token)
        cmd = "cd #{userfolder};git clone https://#{token}@gist.github.com/#{gist.id}"
      else
        cmd = "cd #{userfolder};git clone git@gist.github.com:#{gist.id}"

      shell.exec cmd, (code, huh, message) ->
        if code or message
          console.log gist.id, user, code, message
        else
          console.log "cloned #{gist.id} into #{user}'s folder'"
        setTimeout ->
          gistCb()
        , 250 + Math.random() * 500

gistPuller = (gist, gistCb) ->
###
# TODO: pull inside existing repositories
console.log("exists, pulling", gist.id)
shell.cd gist.id
shell.exec 'git pull origin master', (code, huh, message) ->
  console.log("pulled", gist.id)
  return gistCb()
###
module.exports =
  gistCloner: gistCloner

if require.main == module
  fs.mkdir base, ->

  # specify the file to load, will probably be data/latest.json for our cron job
  metaFile = process.argv[2] || 'data/gist-meta.json'

  username = process.argv[3] || ""

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
  if username
    list = gistMeta.filter (d) -> return d.owner.login == username
  else
    list = gistMeta


  console.log "number of gists", list.length
  if singleId or ids
    async.each gistMeta, gistCloner, done
  else
    async.eachLimit list, 5, gistCloner, done
    #async.eachSeries gistMeta, gistCloner, done
