/*
Generate summaries of our data, whether its downloaded gists or known users
Should be able to summarize by user as well
*/

const fs = require('fs');
const d3 = require('d3');
const Table = require('cli-table');

const base = __dirname + '/data/gists-clones/';

// count gists in file download folder

// count gists in clone folder

const getGistsPerUser = function(meta) {
  const nested = d3
    .nest()
    .key(d(() => d.owner.login))
    .rollup(leaves => leaves.map(d(() => d.id)))
    .entries(meta);
  return nested;
};

const countGistsPerUser = function(meta) {
  const nested = d3
    .nest()
    .key(d => d.owner.login)
    .rollup(leaves => leaves.length)
    .entries(meta);
  return nested;
};

// count cloned gists per user
const countClonedGistsForUser = function(user) {
  try {
    const dir = fs.readdirSync(base + user);
    return dir.length;
  } catch (e) {
    return 0;
  }
};

const percent = function(num, den) {
  let p = num / den * 100;
  p = Math.round(p * 100) / 100;
  return p + '%';
};

if (require.main === module) {
  // specify the file that lists the gists we want to analyze
  const metaFile = process.argv[2] || 'data/gist-meta.json';
  const gistMeta = JSON.parse(fs.readFileSync(metaFile).toString());

  const usersHash = {};
  const userCounts = countGistsPerUser(gistMeta);
  userCounts.forEach(function(u) {
    const user = (usersHash[u.key] = { login: u.key, count: u.values });
    const clones = countClonedGistsForUser(u.key);
    return (user.clones = clones);
  });

  const limit = 20;
  console.log(
    `SHOWING ${limit} of ${userCounts.length} users, with ${gistMeta.length} blocks total`
  );
  const users = Object.keys(usersHash).map(username => usersHash[username]);
  let count = 0;
  let clones = 0;
  users.forEach(function(user) {
    count += user.count;
    return (clones += user.clones);
  });
  console.log(`${percent(clones, count)}% cloned with ${clones}/${count}`);

  users.sort((a, b) => b.count - a.count);

  const table = new Table({
    head: ['login', 'percent', 'count', 'clones']
    //, colWidths: [150, 50, 50]
  });

  users
    .slice(0, limit)
    .forEach(u =>
      table.push([u.login, percent(u.clones, u.count), u.count, u.clones])
    );
  //console.log(`${u.login}\t\t\t| count: ${u.count}\t\t| clones: ${u.clones}`);

  console.log(table.toString());
}
