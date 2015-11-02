Download and parse blocks for indexing by API
Data used for [visualizing all the blocks](http://bl.ocks.org/enjalot/1d679f0322174b65d032)

## usage

### Config.js
You will need to create `config.js` before running any of the below commands, you can copy `config.js.example` and replace the placeholders with [application tokens](https://github.com/settings/applications/new)

### List of users to scrape

There are several files related to users. The "authoratative" file listing users that have at least 1 public gist can be found in `data/usables.csv`
This is generated with the command:
```
coffee users.coffee
```
This requires data/users-combined.csv to exist, which will have the header "username" and one line per username.  
a user list can be downloaded from the [bl.ocksplorer.org form results](https://docs.google.com/spreadsheet/pub?key=0Al5UYaVoRpW3dE12bzRTVEp2RlJDQXdUYUFmODNiTHc&single=true&gid=0&output=csv)

There is also `combine-users.coffee` which allows you to combine 


### Block metadata

A list of gist metadata for gists that are valid blocks (contain index.html) pulled from public gists of everybody
listed in `data/usables.csv`

```
# generate data/gist-meta.json, the list of all blocks
coffee gist-meta.coffee
```
This outputs to `data/gist-meta.json` which can then be used to generate the blocks

### Parsed blocks
```
coffee gist-content.coffee
```

This will output to `data/blocks.json` with the count of each api function used added to the gist metadata, as well as the file metadata stripped away to save space.  
This works by iterating through all the blocks in `data/gist-meta.json` and downloading the raw html/js files and parsing out d3 functions from them.

I'm considering having this save all the pulled down files to disk for further processing.


### Custom gallery JSON

I wanted a script that would take in a list of block URLS and give me a subset of the `blocks.json` formatted data. It currently depends on the blocks being part of the list, so anonymous blocks won't work right now.

```
coffee gallery.coffee data/unconf.csv data/out.json
```