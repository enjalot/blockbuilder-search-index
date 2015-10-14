Download and parse blocks for indexing by API
Data used for [visualizing all the blocks](http://bl.ocks.org/enjalot/1d679f0322174b65d032)

## usage

### generate a list of users with at least 1 gist
this requires data/users.csv to exist, which will have the header "username" and one line per username.  
a user list can be downloaded from the [bl.ocksplorer.org form results](https://docs.google.com/spreadsheet/pub?key=0Al5UYaVoRpW3dE12bzRTVEp2RlJDQXdUYUFmODNiTHc&single=true&gid=0&output=csv)
```
coffee users.coffee
```

A list of gist metadata for gists that are valid blocks (contain index.html)
This requires config.js to be setup with a github application key, to avoid rate-limiting (currently takes about 400 requests to download everyone's gists)

```
# generate data/gist-meta.json, the list of all blocks
coffee gist-meta.coffee
```
This outputs to `data/gist-meta.json` which can then be used to generate the blocks
```
coffee gist-content.coffee
```
This will output to `data/blocks.json` with the count of each api function used added to the gist metadata, as well as the file metadata stripped away to save space.