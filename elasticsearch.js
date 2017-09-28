const fs = require('fs');
const d3 = require('d3');
const async = require('async');
const request = require('request');
const path = require('path');

const parse = require('./parse.coffee');

const elasticsearch = require('elasticsearch');
const esConfig = require('./config.js').elasticsearch;
const client = new elasticsearch.Client({
  host: esConfig.host
  //log: 'trace'
});

// number of missing files
const missing = 0;

// we may want to check if a document is in ES before trying to write it
// this can help us avoid overloading the server with writes when reindexing
let skip = false;
let offset = 0;

const done = function(err) {
  console.log('done');
  console.log(`skipped ${missing} missing files`);
  if (err) {
    console.log('err', err);
  }
  return process.exit();
};

const pruneES = function(gist) {
  // the JSON we will be sending to elasticsearch
  let commit, split;
  const pruned = {
    userId: (gist.owner != null ? gist.owner.login : undefined) || 'anonymous',
    description: gist.description,
    created_at: gist.created_at,
    updated_at: gist.updated_at,
    api: Object.keys(gist.api || {}),
    d3version: gist.d3version,
    d3modules: Object.keys(gist.d3modules || {}),
    colors: Object.keys(gist.colors || {}),
    //tags: gist.tags || [],
    //files:
    readme: gist.readme || '',
    code: gist.code || '',
    filenames: Object.keys(gist.files)
  };

  const thumb =
    gist.files['thumbnail.png'] != null
      ? gist.files['thumbnail.png'].raw_url
      : undefined;
  if (gist.files['thumbnail.png']) {
    //pruned.thumbnail = gist.files["thumbnail.png"].raw_url
    split = thumb.split('/raw/');
    commit = split[1].split('/thumbnail.png')[0];
    pruned.thumb = commit;
  }
  const preview =
    gist.files['preview.png'] != null
      ? gist.files['preview.png'].raw_url
      : undefined;
  if (gist.files['preview.png']) {
    split = preview.split('/raw/');
    commit = split[1].split('/preview.png')[0];
    pruned.preview = commit;
  }

  return pruned;
};

const processed = 0;
let i = 0;
const gistParser = function(gist, gistCb) {
  //console.log("NOT RETURNING", gist.id, singleId);
  //console.log("gist", gist.id);
  i += 1;
  const index = i + 0;
  if (!(gist != null ? gist.files : undefined)) {
    return setImmediate(gistCb);
  }
  if (!(gist != null ? gist.owner : undefined)) {
    return setImmediate(gistCb);
  }
  const fileNames = Object.keys(gist.files);
  // per-gist cache of api functions that we build up in place
  const gapiHash = {};
  const gcolorHash = {};
  const gmoduleHash = {};
  //const folder = __dirname + "/" + "data/gists-files/" + gist.id;
  const folder =
    __dirname + `/data/gists-clones/${gist.owner.login}/${gist.id}`;

  return async.each(
    fileNames,
    function(fileName, fileCb) {
      const ext = path.extname(fileName).toLowerCase();
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
        const file = folder + '/' + fileName;
        return fs.readFile(file, function(err, data) {
          let numColors;
          if (!data) {
            return fileCb();
          }
          const contents = data.toString();
          // save the string back on the file
          gist.files[fileName].content = contents;
          if (fileName.toLowerCase() === 'index.html') {
            gist.d3version = parse.d3version(contents);
            parse.d3modules(contents, gmoduleHash);
          }
          if (['.html', '.js', '.coffee'].includes(ext)) {
            const numApis = parse.api(contents, gist, gapiHash);
            numColors = parse.colors(contents, gist, gcolorHash);
            parse.colorScales(gapiHash, gcolorHash);
            //console.log(gist.id, fileName, numApis, numColors);
            return fileCb();
          } else if (['.md'].includes(ext)) {
            // pull out "hashtags"
            // TODO: come up with a hashtag convention that doesn't get confused with
            // markdown and hash-urls
            /*
          const hashtag = /^#[a-zA-Z].?[\s\,]/g;
          const tags = contents.match(hashtag);
          if (tags && tags.length) {
            console.log(gist.id, "tags", tags);
            gist.tags = tags;
          }
          */
            // TODO: pull out user @-mentions
            return fileCb();
          } else if (['.tsv', '.csv'].includes(ext)) {
            // pull out # of rows and # of columns
            return fileCb();
          } else if (['.css'].includes(ext)) {
            numColors = parse.colors(contents, gist, gcolorHash);
            //console.log(gist.id, fileName, 0, numColors);
            return fileCb();
          } else {
            //console.log(gist.id, fileName);
            return fileCb();
          }
        });
      } else {
        return setImmediate(fileCb);
      }
    },
    function() {
      if (Object.keys(gapiHash).length > 0) {
        gist.api = gapiHash;
      }

      if (Object.keys(gcolorHash).length > 0) {
        gist.colors = gcolorHash;
      }

      if (Object.keys(gmoduleHash).length > 0) {
        gist.d3modules = gmoduleHash;
      }

      if (gist.files['thumbnail.png']) {
        gist.thumbnail = gist.files['thumbnail.png'].raw_url;
      }
      if (gist.files['preview.png']) {
        gist.thumbnail = gist.files['preview.png'].raw_url;
      }

      // TODO make this more robust
      if (gist.files['README.md']) {
        gist.readme = gist.files['README.md'].content;
      }
      if (gist.files['readme.md']) {
        gist.readme = gist.files['readme.md'].content;
      }

      // for now we will just index
      if (gist.files['index.html']) {
        gist.code = gist.files['index.html'].content;
      }

      if (!gist.owner) {
        return gistCb();
      }

      const es = pruneES(gist);
      //console.log("ES", JSON.stringify(es));
      if (skip) {
        return client.get(
          {
            index: 'blockbuilder',
            type: 'blocks',
            id: gist.id
          },
          function(err) {
            if (err) {
              // post to elastic search, we don't have it indexed yet
              return client.index(
                {
                  index: 'blockbuilder',
                  type: 'blocks',
                  id: gist.id,
                  body: es
                },
                function(err) {
                  console.log('indexed~', offset + index, gist.id);
                  return gistCb(err);
                }
              );
            } else {
              console.log('already', offset + index, gist.id);
              return setTimeout(() => gistCb(), Math.random() * 50 + 50);
            }
          }
        );
      } else {
        // post to elastic search
        return client.index(
          {
            index: 'blockbuilder',
            type: 'blocks',
            id: gist.id,
            body: es
          },
          function(err) {
            console.log('indexed', offset + index, gist.id);
            return setTimeout(() => gistCb(err), Math.random() * 50 + 50);
          }
        );
      }
    }
  );
};

const deleteGist = (gistId, gistCb) =>
  client.delete(
    {
      index: 'blockbuilder',
      type: 'blocks',
      id: gistId
    },
    function(err, response) {
      console.log('deleted', gistId);
      return gistCb(err, response);
    }
  );

module.exports = {
  gistParser,
  deleteGist,
  prune: pruneES
};

if (require.main === module) {
  // specify the file to load, will probably be data/latest.json for our cron job
  const metaFile = process.argv[2] || __dirname + '/data/gist-meta.json';
  if (process.argv[3] === 'skip') {
    skip = true;
  }
  offset = +process.argv[4] || 0;

  // read in the list of gist metadata
  const gistMeta = JSON.parse(fs.readFileSync(metaFile).toString());
  console.log(gistMeta.length, 'gists');

  // I started running into request timeouts and memory errors
  // when trying to do all 11k at once. I realized I could skip ones
  // already indexed by slicing the array past whats already been indexed
  // (gist-meta is an ordered array, new gists are appended to it)
  async.eachLimit(gistMeta.slice(offset), 20, gistParser, done);
}
//async.eachLimit(gistMeta, 20, gistParser, done);
