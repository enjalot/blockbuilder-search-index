
fs = require 'fs'
d3 = require 'd3'
async = require 'async'
request = require 'request'
path = require 'path'


# read in the list of gist metadata
gistMeta = JSON.parse fs.readFileSync(__dirname + '/data/gist-meta.json').toString()
latest = JSON.parse fs.readFileSync(__dirname + '/data/latest.json').toString()
console.log gistMeta.length
console.log latest.length
console.log gistMeta[0]
console.log latest[0]

merged = gistMeta.concat latest

outFile = __dirname + '/data/gist-meta.json';
fs.writeFileSync outFile, JSON.stringify(merged)