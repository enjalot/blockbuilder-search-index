/**
 * Given a list of users and a time constraint:
 * Get the gist metadata from the GitHub API and push it into Datastore
 * from the GitHub API and push it into Datastore
 * Trigger the "clone" PubSub topic when done
 */

const exec = require('child_process').exec;
const fs = require('fs');
const async = require('async')
// our secrets file with github tokens
const conf = require('./config.js');
const util = require('./util.js');

const Datastore = require('@google-cloud/datastore');
// Instantiates a client, make sure to get a keyfile and set these parameters
// dev code:
const gcpConf = require('../../../config.js').gcp;
const datastore = Datastore({
  projectId: gcpConf.projectId,
  keyFilename: gcpConf.keyFilename,
  namespace: 'gists'
});

// TODO: rename to getGists and redeploy (update documentaiton in issues)
exports.getGists = function (event, callback) {
  const pubsubMessage = event.data;
  console.log("EVENT", event)
  var data = pubsubMessage;
  if(pubsubMessage.data) {
    const message = Buffer.from(pubsubMessage.data, 'base64').toString();
    try {
      data = JSON.parse(message)
    } catch(e) {
      return callback()
    }
  }
  if(!data) {
    console.error({message: "ERROR: no pubsub message"})
    callback()
  }
  console.log(`Processing: ${JSON.stringify(data, null, 2)}`);
  const users = data.users;
  const since = util.processSince(data.since);

  // we collect the gists outside of the async call
  const newGists = [];
  async.eachLimit(users, 5, function(user, userCb) {
    console.log("fetching gists for username")
    util.getPages(user, [], 1, since, function(gists) {
      console.log(`done with ${user}, found ${gists.length} gists`);
      gists.forEach(g => newGists.push(g));
      // upsert the gists into datastore
      entities = gists.map(function(g) {

        // datastore doesn't like keys that have . in them
        // so we replace . with |
        var files = Object.keys(g.files)
        var gfiles = {}
        files.forEach(function(f) {
          gfiles[f.replace(/\./g, '|')] = g.files[f]
        })
        g.files = gfiles;
        // we store the owner login and id on the entity
        if(g.owner) {
          g.owner_login = g.owner.login
          g.owner_id = g.owner.id
        } else {
          g.owner_login = anonymous
          g.owner_id = -1
        }
        // remove extra cruft around user
        delete g.owner;
        var entity = {
          key: datastore.key(['gist', g.id]),
          data: g
        }
        return entity
      })
      datastore.upsert(entities, (err, result) => {
        if(err) {
          console.error(err)
        } else {
          console.log(`upserted ${entities.length} entities.`)
        }
      })
      return setTimeout(() => userCb()
      , 50);
    })
  }, function() {
    console.log("done. number of new gists:", newGists.length);
    console.log("sample gist", JSON.stringify(newGists[0], null, 2))
    callback();
  })

  // exec(`cd /tmp;mkdir enjalot;cd enjalot;git clone https://${conf.github.token}@gist.github.com/f973a941606aa38fed321fbce0c8bd7f`, { stdio: 'ignore' }, (err, stdout) => {
  //   if (err) {
  //     console.error('Failed to use git.', err);
  //   } else {
  //     console.log("success!!")
  //     var html = fs.readFileSync("/tmp/enjalot/f973a941606aa38fed321fbce0c8bd7f/index.html").toString()
  //     console.log("HTML!!!", html)
  //   }
  //   callback();
  // })
};
