fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'

listFile = process.argv[2]
console.log "list file", listFile

listStr = fs.readFileSync(listFile).toString()

list = d3.csv.parse listStr
console.log "list\n", list.length

blocksList = JSON.parse(fs.readFileSync("data/blocks.json").toString() || "[]")
#blocksList = JSON.parse(fs.readFileSync("data/gist-meta.json").toString() || "[]")
blocks = {}
blocksList.forEach (block) ->
  blocks[block.id] = block

thumbed = []
list.forEach (link) ->
  splitted = link.url.split("/")
  user = splitted[3]
  id = splitted[4]
  block = blocks[id]
  if block
    console.log "block", user, id
    if block.thumbnail
      thumbed.push block
  else
    console.log "no block", user, id

console.log "#{thumbed.length} blocks with thumbnails out of #{list.length}"
fs.writeFileSync "data/gallery.json", JSON.stringify(thumbed)