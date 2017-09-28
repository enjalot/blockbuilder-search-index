const fs = require('fs');
const d3 = require('d3');
const async = require('async');
const request = require('request');
const path = require('path');

const allBlocks = [];

// minimal metadata
const minBlocks = [];

// we want an object for each file, with associated gist metadata
let fileBlocks = [];

// global cache of all api functions
const apiHash = {};
// global collection of blocks for API data
const apiBlocks = [];

const colorHash = {};
const colorBlocks = [];
const colorBlocksMin = [];

// libararies and their versions
const libHash = {};
const libBlocks = [];

const moduleHash = {};

// number of missing files
const missing = 0;

const colorNames = d3.csv.parse(
  fs.readFileSync(__dirname + '/data/colors.csv').toString()
);

const categoryColors = {
  'd3.scale.category10': [
    '#1f77b4',
    '#ff7f0e',
    '#2ca02c',
    '#d62728',
    '#9467bd',
    '#8c564b',
    '#e377c2',
    '#7f7f7f',
    '#bcbd22',
    '#17becf'
  ],
  'd3.scale.category20': [
    '#1f77b4',
    '#aec7e8',
    '#ff7f0e',
    '#ffbb78',
    '#2ca02c',
    '#98df8a',
    '#d62728',
    '#ff9896',
    '#9467bd',
    '#c5b0d5',
    '#8c564b',
    '#c49c94',
    '#e377c2',
    '#f7b6d2',
    '#7f7f7f',
    '#c7c7c7',
    '#bcbd22',
    '#dbdb8d',
    '#17becf',
    '#9edae5'
  ],
  'd3.scale.category20b': [
    '#393b79',
    '#5254a3',
    '#6b6ecf',
    '#9c9ede',
    '#637939',
    '#8ca252',
    '#b5cf6b',
    '#cedb9c',
    '#8c6d31',
    '#bd9e39',
    '#e7ba52',
    '#e7cb94',
    '#843c39',
    '#ad494a',
    '#d6616b',
    '#e7969c',
    '#7b4173',
    '#a55194',
    '#ce6dbd',
    '#de9ed6'
  ],
  'd3.scale.category20c': [
    '#3182bd',
    '#6baed6',
    '#9ecae1',
    '#c6dbef',
    '#e6550d',
    '#fd8d3c',
    '#fdae6b',
    '#fdd0a2',
    '#31a354',
    '#74c476',
    '#a1d99b',
    '#c7e9c0',
    '#756bb1',
    '#9e9ac8',
    '#bcbddc',
    '#dadaeb',
    '#636363',
    '#969696',
    '#bdbdbd',
    '#d9d9d9'
  ]
};
const categories = Object.keys(categoryColors);

const done = function(err) {
  console.log('done'); //, apiHash
  console.log(`skipped ${missing} missing files`);
  fs.writeFileSync('data/parsed/apis.json', JSON.stringify(apiHash));
  fs.writeFileSync('data/parsed/colors.json', JSON.stringify(colorHash));
  fs.writeFileSync('data/parsed/blocks.json', JSON.stringify(allBlocks));
  fs.writeFileSync('data/parsed/blocks-min.json', JSON.stringify(minBlocks));
  fs.writeFileSync('data/parsed/blocks-api.json', JSON.stringify(apiBlocks));
  fs.writeFileSync(
    'data/parsed/blocks-colors.json',
    JSON.stringify(colorBlocks)
  );
  fs.writeFileSync(
    'data/parsed/blocks-colors-min.json',
    JSON.stringify(colorBlocksMin)
  );
  fs.writeFileSync('data/parsed/files-blocks.json', JSON.stringify(fileBlocks));

  let libcsv = 'url,count\n';
  Object.keys(libHash).forEach(
    lib => (libcsv += lib + ',' + libHash[lib] + '\n')
  );
  fs.writeFileSync('data/parsed/libs.csv', libcsv);

  let modulescsv = 'module,count\n';
  Object.keys(moduleHash).forEach(
    module => (modulescsv += module + ',' + moduleHash[module] + '\n')
  );
  fs.writeFileSync('data/parsed/modules.csv', modulescsv);

  if (err) {
    console.log('err', err);
  }
  console.log(`wrote ${apiBlocks.length} API blocks`);
  console.log(`wrote ${colorBlocks.length} Color blocks`);
  console.log(`wrote ${fileBlocks.length} Files blocks`);
  return console.log(`wrote ${allBlocks.length} total blocks`);
};

// read in the list of gist metadata
const gistMeta = JSON.parse(
  fs.readFileSync(__dirname + '/data/gist-meta.json').toString()
);
console.log(gistMeta.length);

const pruneMin = function(gist) {
  const pruned = {
    id: gist.id,
    userId: gist.owner.login,
    description: gist.description,
    created_at: gist.created_at,
    updated_at: gist.updated_at
  };
  if (gist.files['thumbnail.png']) {
    pruned.thumbnail = gist.files['thumbnail.png'].raw_url;
  }
  return pruned;
};

const pruneApi = function(gist) {
  const pruned = {
    id: gist.id,
    userId: gist.owner.login,
    //userId: gist.userId,
    description: gist.description,
    created_at: gist.created_at,
    updated_at: gist.updated_at,
    api: gist.api
    //files: gist.files
  };
  if (gist.files['thumbnail.png']) {
    pruned.thumbnail = gist.files['thumbnail.png'].raw_url;
  }
  return pruned;
};

const pruneColors = function(gist) {
  const pruned = {
    id: gist.id,
    userId: gist.owner.login,
    //userId: gist.userId,
    description: gist.description,
    created_at: gist.created_at,
    updated_at: gist.updated_at,
    colors: gist.colors
  };
  if (gist.files['thumbnail.png']) {
    pruned.thumbnail = gist.files['thumbnail.png'].raw_url;
  }
  return pruned;
};

const pruneColorsMin = function(gist) {
  const pruned = {
    i: gist.id,
    u: gist.owner.login,
    c: Object.keys(gist.colors) || []
  };
  const th =
    gist.files['thumbnail.png'] != null
      ? gist.files['thumbnail.png'].raw_url
      : undefined;
  if (th) {
    const split = th.split('/raw/');
    const commit = split[1].split('/thumbnail.png')[0];
    pruned.t = commit;
  }

  // if (gist.files["thumbnail.png"]) {
  //   pruned.thumbnail = gist.files["thumbnail.png"].raw_url;
  // }
  return pruned;
};

const pruneFiles = function(gist) {
  const fileNames = Object.keys(gist.files);
  const prunes = [];
  fileNames.forEach(function(fileName) {
    const file = gist.files[fileName];
    const pruned = {
      gistId: gist.id,
      userId: gist.userId,
      description: gist.description,
      created_at: gist.created_at,
      updated_at: gist.updated_at,
      fileName,
      file
    };
    return prunes.push(pruned);
  });
  return prunes;
};

const parseD3Functions = function(code) {
  // we match d3.foo.bar( which will find plugins and unofficial api functions
  const re = new RegExp(/d3\.[a-zA-Z0-9\.]*?\(/g);
  const matches = code.match(re) || [];
  return matches;
};

const parseApi = function(code, gist, gapiHash) {
  const apis = parseD3Functions(code);
  apis.forEach(function(api) {
    api = api.slice(0, api.length - 1);
    //if (!apiHash[api]) { apiHash[api] = 0; }
    //apiHash[api]++;
    if (!gapiHash[api]) {
      gapiHash[api] = 0;
    }
    return gapiHash[api]++;
  });
  return apis.length;
};

const colorScales = function(gapiHash, gcolorHash) {
  categories.forEach(function(cat) {
    if (gapiHash[cat]) {
      const colors = categoryColors[cat];
      return colors.forEach(function(color) {
        //if (!colorHash[color]) { colorHash[color] = 0; }
        //colorHash[color]++;
        if (!gcolorHash[color]) {
          gcolorHash[color] = 0;
        }
        return gcolorHash[color]++;
      });
    }
  });
  return 0;
};

const addColors = function(code, re, gcolorHash) {
  const matches = code.match(re) || [];
  matches.forEach(function(str) {
    const color = d3
      .rgb(str)
      .toString()
      .toLowerCase();
    //if (!colorHash[color]) { colorHash[color] = 0; }
    //colorHash[color]++;
    if (!gcolorHash[color]) {
      gcolorHash[color] = 0;
    }
    return gcolorHash[color]++;
  });
  return 0;
};

const parseColors = function(code, gist, gcolorHash) {
  const hsl = /hsla?\(\s*(\d{1,3})\s*,\s*(\d{1,3}\%)\s*,\s*(\d{1,3}\%)\s*(?:\s*,\s*(\d+(?:\.\d+)?)\s*)?\)/g;
  const hex = /#[a-fA-F0-9]{3,6}/g;
  //someone clever could combine these two
  const rgb = /rgb\((\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})\)/g;
  const rgba = /rgba\((\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})\)/g;
  addColors(code, hsl, gcolorHash);
  addColors(code, hex, gcolorHash);
  addColors(code, rgb, gcolorHash);
  addColors(code, rgba, gcolorHash);
  colorNames.forEach(function(c) {
    const re = new RegExp(c.color, 'gi');
    return addColors(code, re, gcolorHash);
  });

  return Object.keys(gcolorHash).length;
};

const parseScriptTags = function(code) {
  // anything with a // in it (signifiying url...)
  //const re = new RegExp(/<script.*?src=[\"\'](.*?\/\/.+?)[\"\'].*?>/g);
  // anything with a .js in it
  const re = new RegExp(/<script.*?src=[\"\'](.*?\.js.*?)[\"\'].*?>/g);
  const matches = [];
  let match = re.exec(code);
  while (match !== null) {
    matches.push(match[1]);
    match = re.exec(code);
  }
  return matches;
};

const parseLibs = function(code, gist, glibHash) {
  const scripts = parseScriptTags(code);
  scripts.forEach(function(script) {});
  //console.log(script);
  //if (!libHash[script]) { libHash[script] = 0; }
  //libHash[script]++;
  return 0;
};

const parseD3Version = function(code) {
  const scripts = parseScriptTags(code);
  let version = 'NA';
  scripts.forEach(function(script) {
    if (script.indexOf('d3.v4') >= 0) {
      version = 'v4';
    } else if (script.indexOf('d3/3.') >= 0 || script.indexOf('d3.v3') >= 0) {
      version = 'v3';
    }
    if (script.indexOf('d3.v2') >= 0) {
      return (version = 'v2');
    } else if (
      script.indexOf('d3.js') >= 0 ||
      script.indexOf('d3.min.js') >= 0
    ) {
      // we know this is some sort of d3 but not which version
      if (version === 'NA') {
        return (version = 'IDK');
      }
    }
  });
  //console.log(version);
  return version;
};

const parseD3Modules = function(code, gmoduleHash) {
  // finds anything with the pattern d3-*. e.g. d3-legend.js or d3-transition.v1.min.js
  // TODO:
  // d3.geo.projection/raster/tile/polyhedron
  // d3.tip
  const scripts = parseScriptTags(code);
  scripts.forEach(function(script) {
    const re = /(d3-[a-z]*?)\./;
    //module = script.match(re)
    const matches = re.exec(script);
    if (!matches || !matches.length) {
      return;
    }
    const module = matches[1];
    //console.log(module);
    //console.log(script);
    //if (!moduleHash[module]) { moduleHash[module] = 0; }
    //moduleHash[module]++;
    if (!gmoduleHash[module]) {
      gmoduleHash[module] = 0;
    }
    return gmoduleHash[module]++;
  });
  return 0;
};

let i = 0;
const gistParser = function(gist, gistCb) {
  //console.log("NOT RETURNING", gist.id, singleId);
  i++;
  console.log(i, gist.id);
  const fileNames = Object.keys(gist.files);
  // per-gist cache of api functions that we build up in place
  const gapiHash = {};
  const glibHash = {};
  const gmoduleHash = {};
  const gcolorHash = {};
  const folder = __dirname + '/' + 'data/gists-files/' + gist.id;
  fs.mkdir(folder, function() {});

  // we make a simplified data object for each file
  const filepruned = pruneFiles(gist);
  fileBlocks = fileBlocks.concat(filepruned);

  return async.each(
    fileNames,
    function(fileName, fileCb) {
      const ext = path.extname(fileName);
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
          if (fileName === 'index.html') {
            // TODO copy glibHash -> libHash etc for each of these
            const numLibs = parseLibs(contents, gist, glibHash);
            const version = parseD3Version(contents);
            const modules = parseD3Modules(contents, gmoduleHash);
            gist.d3version = version;
          }
          if (['.html', '.js', '.coffee'].includes(ext)) {
            // TODO copy gapiHash -> apiHash etc for each of these
            const numApis = parseApi(contents, gist, gapiHash);
            numColors = parseColors(contents, gist, gcolorHash);
            colorScales(gapiHash, gcolorHash);
            //console.log(gist.id, fileName, numApis, numColors);
            return fileCb();
          } else if (['.tsv', '.csv'].includes(ext)) {
            // pull out # of rows and # of columns
            return fileCb();
          } else if (['.css'].includes(ext)) {
            numColors = parseColors(contents, gist, gcolorHash);
            //console.log(gist.id, fileName, 0, numColors);
            return fileCb();
          } else {
            //console.log(gist.id, fileName);
            return fileCb();
          }
        });
      } else {
        return fileCb();
      }
    },
    function() {
      if (Object.keys(gapiHash).length > 0) {
        gist.api = gapiHash;
        apiBlocks.push(pruneApi(gist));
      }
      if (Object.keys(gmoduleHash).length > 0) {
        gist.d3modules = gmoduleHash;
      }
      if (Object.keys(gcolorHash).length > 0) {
        gist.colors = gcolorHash;
        colorBlocks.push(pruneColors(gist));
        colorBlocksMin.push(pruneColorsMin(gist));
      }
      // if (Object.keys(glibHash).length > 0) {
      //   gist.libs = glibHash;
      // }

      //delete gist.files;
      if (gist.files['thumbnail.png']) {
        gist.thumbnail = gist.files['thumbnail.png'].raw_url;
      }
      allBlocks.push(gist);
      minBlocks.push(pruneMin(gist));
      return gistCb();
    }
  );
};

module.exports = {
  api: parseApi,
  colors: parseColors,
  colorScales,
  d3version: parseD3Version,
  d3modules: parseD3Modules
};

if (require.main === module) {
  async.eachLimit(gistMeta, 100, gistParser, done);
}
