/*
Fetch, Clone, Parse and Index a single gist by id
*/

require('coffee-script/register')
var cloner = require('./gist-cloner')
var es = require('./elasticsearch')
var gh = require('./github')

var gistId = process.argv[2]

console.log("getting", gistId)

gh.getGist(gistId, function(err, response, body){
  if(err) return console.log(gistId, err)
  var gist = JSON.parse(body)
  // console.log("GIST", gist)
  //content.gistFetcher(gist, function(err) {
  cloner.gistCloner(gist, function(err) {
    es.gistParser(gist, function(err) {
      return;
    })
  })
})