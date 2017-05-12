
fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'


# read in the list of gist metadata
#gistMeta = JSON.parse fs.readFileSync(__dirname + '/data/gist-meta.json').toString()
#latest = JSON.parse fs.readFileSync(__dirname + '/data/latest.json').toString()
#console.log gistMeta.length
#console.log latest.length
#console.log gistMeta[0]
#console.log latest[0]

#merged = gistMeta.concat latest
#outFile = __dirname + '/data/gist-meta.json';
#fs.writeFileSync outFile, JSON.stringify(merged)

saveGistMeta = (newGists) ->
  try
    blocksList = JSON.parse(fs.readFileSync(__dirname + '/data/gist-meta.json').toString() || "[]")
  catch e
    blocksList = []
  allGists = combine(blocksList, newGists)
  console.log "writing #{allGists.length} blocks to data/gist-meta.json"
  fs.writeFileSync __dirname + '/data/gist-meta.json', JSON.stringify(allGists)
  return

# this function combines the new gist meta-data with what we may have already
# gotten before. This allows us to accumulate new blocks incrementally
combine = (oldGists, newGists) ->
  console.log "combining #{newGists.length} with #{oldGists.length} existing blocks"
  blocks = {}
  oldGists.forEach (block) ->
    blocks[block.id] = block

  newGists.forEach (gist) ->
    blocks[gist.id] = gist

  ids = Object.keys(blocks)
  newBlockList = []
  ids.forEach (id) ->
    newBlockList.push blocks[id]
  return newBlockList

infile = process.argv[2] || "data/new.json"
try
  inblocks = JSON.parse(fs.readFileSync(__dirname + '/' + infile).toString() || "[]")
catch e
  inblocks = []

saveGistMeta(inblocks)

