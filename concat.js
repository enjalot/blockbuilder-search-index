let inblocks;
const fs = require('fs');
const d3 = require('d3');
const async = require('async');
const request = require('request');
const path = require('path');

// read in the list of gist metadata
// const gistMeta = JSON.parse(fs.readFileSync(__dirname + '/data/gist-meta.json').toString());
// const latest = JSON.parse(fs.readFileSync(__dirname + '/data/latest.json').toString());
// console.log(gistMeta.length);
// console.log(latest.length);
// console.log(gistMeta[0]);
// console.log(latest[0]);

//merged = gistMeta.concat latest
// const outFile = __dirname + '/data/gist-meta.json';
// fs.writeFileSync(outFile, JSON.stringify(merged));

const saveGistMeta = function(newGists) {
  let blocksList;
  try {
    blocksList = JSON.parse(
      fs.readFileSync(__dirname + '/data/gist-meta.json').toString() || '[]'
    );
  } catch (e) {
    blocksList = [];
  }
  const allGists = combine(blocksList, newGists);
  console.log(`writing ${allGists.length} blocks to data/gist-meta.json`);
  fs.writeFileSync(
    __dirname + '/data/gist-meta.json',
    JSON.stringify(allGists)
  );
};

// this function combines the new gist meta-data with what we may have already
// gotten before. This allows us to accumulate new blocks incrementally
var combine = function(oldGists, newGists) {
  console.log(
    `combining ${newGists.length} with ${oldGists.length} existing blocks`
  );
  const blocks = {};
  oldGists.forEach(block => (blocks[block.id] = block));

  newGists.forEach(gist => (blocks[gist.id] = gist));

  const ids = Object.keys(blocks);
  const newBlockList = [];
  ids.forEach(id => newBlockList.push(blocks[id]));
  return newBlockList;
};

const infile = process.argv[2] || 'data/new.json';
try {
  inblocks = JSON.parse(
    fs.readFileSync(__dirname + '/' + infile).toString() || '[]'
  );
} catch (error) {
  const e = error;
  inblocks = [];
}

saveGistMeta(inblocks);
