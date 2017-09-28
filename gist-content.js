const fs = require('fs');
const d3 = require('d3');
const async = require('async');
const request = require('request');
const path = require('path');
const shell = require('shelljs');

// we will log our progress in ES
const elasticsearch = require('elasticsearch');
const esConfig = require('./config.js').elasticsearch;
const client = new elasticsearch.Client(esConfig);

const base = __dirname + '/data/gists-files/';
const timeouts = [];

const done = function(err, pruned) {
  console.log('done writing files');
  if (timeouts.length) {
    console.log('timeouts', timeouts);
  }
  if (singleId) {
    console.log('single id', singleId);
    return;
  }
  if (ids) {
    console.log('ids', ids);
    return;
  }
  // log to elastic search
  const summary = {
    script: 'content',
    timeouts,
    filename: metaFile,
    ranAt: new Date()
  };
  return client.index(
    {
      index: 'bbindexer',
      type: 'scripts',
      body: summary
    },
    function(err, response) {
      console.log('indexed');
      return process.exit();
    }
  );
};

const gistFetcher = function(gist, gistCb) {
  if (!gist) {
    return setImmediate(gistCb);
  }
  if (!gist.files) {
    return setImmediate(gistCb);
  }
  if (ids && !Array.from(ids).includes(gist.id)) {
    return setImmediate(gistCb);
  }
  if (singleId && gist.id !== singleId) {
    return setImmediate(gistCb);
  }
  //console.log("NOT RETURNING", gist.id, singleId);
  const fileNames = Object.keys(gist.files);
  const folder = base + gist.id;
  fs.mkdir(folder, function() {});
  return async.each(
    fileNames,
    function(fileName, fileCb) {
      const ext = path.extname(fileName).toLowerCase();
      const filePath = folder + '/' + fileName;
      if (skipExisting) {
        try {
          if (fs.lstatSync(filePath)) {
            // if it exists we skip it
            console.log('skipping', gist.id, fileName);
            return setImmediate(fileCb);
          }
        } catch (e) {}
      }
      // otherwise we just continue
      if (
        [
          '.html',
          '.js',
          '.coffee',
          '.md',
          '.json',
          '.csv',
          '.tsv',
          '.css'
        ].includes(ext)
      ) {
        const file = gist.files[fileName];
        return request.get(file.raw_url, function(err, response, body) {
          //console.log(err, response, typeof body !== 'undefined' && body !== null ? body.length : undefined);
          if (err) {
            console.log('timeout', gist.id);
            timeouts.push(gist.id);
            console.log(filePath, err);
          }
          if (!body) {
            return fileCb();
          }
          //console.log("writing body", body);
          return fs.writeFile(filePath, body, function() {
            console.log(gist.id, fileName);
            return setTimeout(() => fileCb(), Math.random() * 150 + 150);
          });
        });
      } else {
        return setImmediate(fileCb);
      }
    },
    () => gistCb()
  );
};

module.exports = { gistFetcher };

if (require.main === module) {
  //const base = __dirname + "/data/gists-clones/";
  var ids, left, singleId;
  fs.mkdir(base, function() {});

  // specify the file to load, will probably be data/latest.json for our cron job
  var metaFile = process.argv[2] || 'data/gist-meta.json';
  // skip existing files (faster for huge dump, but we want to update latest files)
  var skipExisting =
    (left = process.argv[3] === 'skip') != null ? left : { true: false };

  // optionally pass in a csv file or a single id to be downloaded
  const param = process.argv[4];
  if (param) {
    if (param.indexOf('.csv') > 0) {
      // list of ids to parse
      ids = d3.csv.parse(fs.readFileSync(singleId).toString());
    } else {
      singleId = param;
      console.log('doing content for single block', singleId);
    }
  }

  const gistMeta = JSON.parse(fs.readFileSync(metaFile).toString());
  console.log('number of gists', gistMeta.length);
  if (singleId || ids) {
    async.each(gistMeta, gistFetcher, done);
  } else {
    async.eachLimit(gistMeta, 10, gistFetcher, done);
  }
}
