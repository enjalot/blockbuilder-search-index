d3 = require 'd3'
request = require 'request'
fs = require 'fs'


userDoc = "https://docs.google.com/spreadsheet/pub?key=0Al5UYaVoRpW3dE12bzRTVEp2RlJDQXdUYUFmODNiTHc&single=true&gid=0&output=csv";

userHash = {}

string = fs.readFileSync('data/mongo-users.json').toString()
string.split("\n").forEach (userStr) ->
  try
    user = JSON.parse(userStr)
    return unless user?.login
    userHash[user.login] = 1
  catch e

usernames = Object.keys(userHash)
console.log("#{usernames.length} users in bb")

userscsv = fs.readFileSync('data/users.csv').toString()
d3.csv.parse userscsv, (user) ->
  username = user["username"]?.toLowerCase()
  return unless username
  userHash[username] = 1

usernames = Object.keys(userHash)
console.log("#{usernames.length} bb + users.csv")

column = 'Provide a github username to the person whose blocks (gists) we should scan for d3 API usage'
request.get userDoc, (err, response, body) ->
  d3.csv.parse body, (user) ->
    username = user[column]?.toLowerCase()
    return unless username
    userHash[username] = 1


  usernames = Object.keys(userHash)
  console.log("#{usernames.length} users total (after blocksplorer)")

  users =  "username\n" + usernames.join("\n")

  fs.writeFileSync("data/users-combined.csv", users)

