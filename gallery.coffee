fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'

listFile = process.argv[2]
outFile = process.argv[3]
console.log "list file", listFile

listStr = fs.readFileSync(listFile).toString()

list = d3.csv.parse listStr
console.log "list\n", list.length

blocksList = JSON.parse(fs.readFileSync("data/blocks-api.json").toString() || "[]")
#blocksList = JSON.parse(fs.readFileSync("data/gist-meta.json").toString() || "[]")
blocks = {}
blocksList.forEach (block) ->
  blocks[block.id] = block

gblocks = []
ids = []
list.forEach (link) ->
  splitted = link.url.split("/")
  user = splitted[3]
  id = splitted[4]
  ids.push id
  block = blocks[id]
  if block
    console.log "block", user, id
    #if block.thumbnail
    gblocks.push block
  else
    console.log "no block", user, id

console.log "#{gblocks.length} blocks found out of #{list.length}"
fs.writeFileSync outFile, JSON.stringify(gblocks)
#fs.writeFileSync "data/gallery.json", JSON.stringify(gblocks)
#fs.writeFileSync "data/unconfIds.csv", "id\n" + ids.join("\n")