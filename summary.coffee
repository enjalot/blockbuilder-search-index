###
Generate summaries of our data, whether its downloaded gists or known users
Should be able to summarize by user as well
###

fs = require 'fs'
d3 = require 'd3'

base = __dirname + "/data/gists-clones/"

# count gists in file download folder

# count gists in clone folder

getGistsPerUser = (meta) ->
  nested = d3.nest()
    .key(d -> d.owner.login)
    .rollup((leaves) -> leaves.map(d -> d.id))
    .entries(meta)
  return nested

countGistsPerUser = (meta) ->
  nested = d3.nest()
    .key((d) -> d.owner.login)
    .rollup((leaves) -> leaves.length)
    .entries(meta)
  return nested

# count cloned gists per user
countClonedGistsForUser = (user) ->
  try
    dir = fs.readdirSync(base + user)
    return dir.length
  catch e
    return 0



if require.main == module
  # specify the file that lists the gists we want to analyze
  metaFile = process.argv[2] || 'data/gist-meta.json'
  gistMeta = JSON.parse fs.readFileSync(metaFile).toString()

  usersHash = {}
  userCounts = countGistsPerUser(gistMeta)
  userCounts.forEach (u) ->
    user = usersHash[u.key] = { login: u.key, count: u.values }
    clones = countClonedGistsForUser(u.key)
    user.clones = clones



  limit = 20
  console.log "SHOWING #{limit} of #{userCounts.length} users, with #{gistMeta.length} blocks total"
  users = Object.keys(usersHash).map (username) -> usersHash[username]
  users.sort (a,b) ->
    return b.count - a.count

  Table = require('cli-table')

  table = new Table({
      head: ['login', 'percent', 'count', 'clones']
    #, colWidths: [150, 50, 50]
  })

  percent = (num, den) ->
    p = num/den * 100
    p = Math.round(p * 100)/100
    return p + "%"

  users.slice(0,limit).forEach (u) ->
    table.push [u.login, percent(u.clones, u.count), u.count, u.clones]
    #console.log "#{u.login}\t\t\t| count: #{u.count}\t\t| clones: #{u.clones}"

  console.log(table.toString())
