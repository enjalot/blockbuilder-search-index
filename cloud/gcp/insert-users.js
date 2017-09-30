/*
Insert users into Datastore from a CSV file.
parameters: filepath to CSV file
*/

const Datastore = require('@google-cloud/datastore');
const gcpConfig = require('../../config.js').gcp;
const d3 = require('d3')
const fs = require('fs')
const async = require('async')

// Instantiates a client, make sure to get a keyfile and set these parameters
const datastore = Datastore({
  projectId: gcpConfig.projectId,
  keyFilename: gcpConfig.keyFilename,
  namespace: 'users'
});

const filename = process.argv[2]
if(!filename) return console.log("I can't insert without a CSV! Pass in path to file")

fs.readFile(filename, function(err, data) {
  if(err) return console.error(err);
  var rows = d3.csvParse(data.toString());
  var entities = rows.map(function(d) {
    d.created = new Date();
    var entity = {
      key: datastore.key(['user', d.username]),
      data: d
    }
    return entity
  })

  var numEntities  = entities.length
  if(numEntities > 500) {
    var batches = Math.ceil(numEntities/500)
    async.each(d3.range(batches), (batch, batchCb) => {
      console.log(`batch`, batch)
      var start = batch * 500
      var end = (batch + 1) * 500
      var slice = entities.slice(start, end)
      console.log("attempting to upsert slice", start, end)
      datastore.upsert(slice, (err, result) => {
        if(err) {
          console.error(err)
          return batchCb(err)
        } else {
          console.log(`upserted ${slice.length} entities.`)
          return batchCb();
        }
      })
    }, (err) => {
      console.log(`done batching`)
    })
  } else {
    // console.log("rows", rows)
    console.log(`attempting to insert ${entities.length} entities.`)
    // batch inserting is limited to 500 entities at a time
    datastore.upsert(entities, (err, result) => {
      if(err) {
        console.error(err)
      } else {
        console.log(`upserted ${entities.length} entities.`)
      }
    })
  }


  // var user = {
  //   username: name,
  //   source: 'manual',
  //   created: new Date()
  // }
  // const task = {
  //   key: datastore.key(['users', name]),
  //   data: user
  // };
  //
  // // Saves the entity
  // datastore.save(task)
  //   .then(() => {
  //     console.log(`Saved ${task.key.name}: ${task.data.description}`);
  //   })
  //   .catch((err) => {
  //     console.error('ERROR:', err);
  //   });
})
