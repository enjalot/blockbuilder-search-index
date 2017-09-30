/*
Insert users into Datastore from a CSV file
*/

const Datastore = require('@google-cloud/datastore');

const gcpConfig = require('../../config.js').gcp;

// Instantiates a client, make sure to get a keyfile and set these parameters
const datastore = Datastore({
  projectId: gcpConfig.projectId,
  keyFilename: gcpConfig.keyFilename,
  namespace: 'users'
});

// The kind for the new entity
const kind = 'user';
// The name/ID for the new entity
const name = 'test';
// The Cloud Datastore key for the new entity
const taskKey = datastore.key([kind, name]);

// Prepares the new entity
const task = {
  key: taskKey,
  data: {
    source: 'manual',
    created: new Date()
  }
};

// Saves the entity
datastore.save(task)
  .then(() => {
    console.log(`Saved ${task.key.name}: ${task.data.description}`);
  })
  .catch((err) => {
    console.error('ERROR:', err);
  });
