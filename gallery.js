const fs = require('fs');
const d3 = require('d3');
const async = require('async');
const request = require('request');
const path = require('path');

const listFile = process.argv[2];
const outFile = process.argv[3];
console.log('list file', listFile);

const listStr = fs.readFileSync(listFile).toString();

const list = d3.csv.parse(listStr);
console.log('list\n', list.length);

const blocksList = JSON.parse(
  fs.readFileSync('data/parsed/blocks.json').toString() || '[]'
);
// const blocksList = JSON.parse(fs.readFileSync("data/blocks-api.json").toString() || "[]");
// const blocksList = JSON.parse(fs.readFileSync("data/gist-meta.json").toString() || "[]");
const blocks = {};
blocksList.forEach(block => (blocks[block.id] = block));

const gblocks = [];
const ids = [];
list.forEach(function(link) {
  const splitted = link.url.split('/');
  const user = splitted[3];
  const id = splitted[4];
  ids.push(id);
  const block = blocks[id];
  if (block) {
    console.log('block', user, id);
    //if block.thumbnail
    return gblocks.push(block);
  } else {
    return console.log('no block', user, id);
  }
});

console.log(`${gblocks.length} blocks found out of ${list.length}`);
fs.writeFileSync(outFile, JSON.stringify(gblocks));
// fs.writeFileSync("data/gallery.json", JSON.stringify(gblocks));
// fs.writeFileSync("data/unconfIds.csv", `id\n${ids.join("\n")}`);
