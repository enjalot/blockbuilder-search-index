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

const base = __dirname + '/data/gists-clones/';
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

const gistCloner = function(gist, gistCb) {
  // I wanted to actually clone all the repositories but it seems to be less reliable.
  // we get rate limited if we use https:// git urls
  // and the ssh ones disconnect unexpectedly, probably some sort of rate limiting but it doesn't show in
  // curl https://api.github.com/rate_limit
  let user;
  if (ids && !Array.from(ids).includes(gist.id)) {
    return gistCb();
  }
  if (singleId && gist.id !== singleId) {
    return gistCb();
  }
  const { token } = require('./config.js').github;
  //console.log("token", token)
  if (gist.owner) {
    user = gist.owner.login;
  } else {
    user = 'anonymous';
  }

  const userfolder = base + user;
  const folder = userfolder + '/' + gist.id;
  fs.mkdir(userfolder, function() {});

  //shell.cd(userfolder)
  // TODO don't use token in clone url (git init; git pull with token)
  //fs.lstat(folder + "/.git", function(err, stats) {
  return fs.lstat(folder, function(err, stats) {
    // TODO check for files?
    let cmd;
    if (stats && stats.isDirectory()) {
      console.log('already got', gist.id);
      // we want to be able to pull recently modified gists
      cmd = `cd ${userfolder}/${gist.id}; git pull origin master`;
      return shell.exec(cmd, function(code, huh, message) {
        if (code || message) {
          console.log(gist.id, user, code, message);
        } else {
          console.log(`pulled ${gist.id} into ${user}'s folder'`);
        }
        return setTimeout(() => gistCb(), 250 + Math.random() * 500);
      });
    } else {
      if (token) {
        cmd = `cd ${userfolder};git clone https://${token}@gist.github.com/${gist.id}`;
      } else {
        cmd = `cd ${userfolder};git clone git@gist.github.com:${gist.id}`;
      }

      return shell.exec(cmd, function(code, huh, message) {
        if (code || message) {
          console.log(gist.id, user, code, message);
        } else {
          console.log(`cloned ${gist.id} into ${user}'s folder'`);
        }
        return setTimeout(() => gistCb(), 250 + Math.random() * 500);
      });
    }
  });
};

const gistPuller = function(gist, gistCb) {};
/*
* TODO: pull inside existing repositories
console.log("exists, pulling", gist.id);
shell.cd(gist.id);
shell.exec('git pull origin master', function(code, huh, message) {
  console.log("pulled", gist.id);
  return gistCb();
});
*/
module.exports = { gistCloner };

if (require.main === module) {
  var ids, list, singleId;
  fs.mkdir(base, function() {});

  // specify the file to load, will probably be data/latest.json for our cron job
  var metaFile = process.argv[2] || 'data/gist-meta.json';

  const username = process.argv[3] || '';

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
  if (username) {
    list = gistMeta.filter(d => d.owner.login === username);
  } else {
    list = gistMeta;
  }

  console.log('number of gists', list.length);
  if (singleId || ids) {
    async.each(gistMeta, gistCloner, done);
  } else {
    async.eachLimit(list, 5, gistCloner, done);
  }
}
//async.eachSeries(gistMeta, gistCloner, done);
