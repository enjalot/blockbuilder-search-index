/*
Query users from Datastore
Can take parameters
* number of users to fetch
* offset from start
*/

const Datastore = require('@google-cloud/datastore');
const gcpConfig = require('../../config.js').gcp;

// Instantiates a client, make sure to get a keyfile and set these parameters
const datastore = Datastore({
  projectId: gcpConfig.projectId,
  keyFilename: gcpConfig.keyFilename,
  namespace: 'users'
});

var query = datastore.createQuery('users', 'user')
query.order('created')
// .offset(1)

datastore.runQuery(query, (error, entities, info) => {
  entities.forEach(function(d) {
    // console.log("result", d)
    console.log("json", JSON.stringify(d, null, 2))
  })
})
