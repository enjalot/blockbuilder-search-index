/*
  Simple server to receive gists and index them as they come.
 */
var express = require('express')
var bodyParser = require('body-parser')

var config = require('./config.js')

require('coffee-script/register')
//var content = require('./gist-content')
var cloner = require('./gist-cloner')
var es = require('./elasticsearch')
var gh = require('./github')

var app = express()
app.use(bodyParser.json({limit: '50mb'}));
app.use(bodyParser.urlencoded({ extended: true }));

app.get('/index/gist/:gistId', function(req, res) {
  res.status(200).send("Ok"); // we always send OK, this shouldn't interupt app
  var gistId = req.params.gistId;
  console.log(new Date(), "indexing", gistId)
  try {
    gh.getGist(gistId, function(err, response, body){
      if(err) return console.log(gistId, err)
      var gist = JSON.parse(body)
      //content.gistFetcher(gist, function(err) {
      cloner.gistCloner(gist, function(err) {
        es.gistParser(gist, function(err) {
          return;
        })
      })
    })
  } catch (e) {
    console.log(e);
  }
});

app.get('/delete/gist/:gistId', function(req, res) {
  res.status(200).send("Ok"); // we always send OK, this shouldn't interupt app
  var gistId = req.params.gistId
  es.deleteGist(gistId, function(err) {
    return;
  })
});


var port = config.server.port;
var server = app.listen(port, function () {
  //var host = server.address().address;
  //var port = server.address().port;
  console.log('Building Bl.ocks Search Index listening at http://localhost:%s', port);
});
