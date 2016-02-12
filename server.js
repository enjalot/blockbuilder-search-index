/*
  Simple server to receive gists and index them as they come.
 */
var express = require('express')
var bodyParser = require('body-parser')

var config = require('./config.js')

require('coffee-script/register')
var content = require('./gist-content')
var es = require('./elasticsearch')

var app = express()
app.use(bodyParser.json({limit: '50mb'}));
app.use(bodyParser.urlencoded({ extended: true }));

app.post('/index/gist', function(req, res) {
  res.status(200).send("Ok"); // we always send OK, this shouldn't interupt app
  var gist = req.body;
  if(!gist) return;
  content.gistFetcher(gist, function(err) {
    es.gistParser(gist, function(err) {
      return;
    })
  })
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
