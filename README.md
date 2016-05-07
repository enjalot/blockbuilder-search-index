## Download and parse blocks for search
This repo is a combination of utility scripts and services that support the continuous scraping and indexing
of public blocks. It powers [Blockbuilder](http://blockbuilder.org)'s [search page](http://blockbuilder.org/search).

[Blocks](https://bl.ocks.org) are stored as GitHub [gists](https://gist.github.com), which are essentially mini git repositories. If a gist has an `index.html` file, d3 example viewers like [blockbuilder.org](blockbuilder.org) or [bl.ocks.org](bl.ocks.org) will render the page contained in the gist.  Given a list of users we can query the [GitHub API](https://developer.github.com/v3/gists/) for the latest public gists that each of those users has updated or created.
We can then filter those gists to see only those gists which have an `index.html` file. 

Once we have a list of gists
from the API we can download the files from each gist to disk for further processing. Then, we want to index some of those files in [Elasticsearch](https://www.elastic.co/products/elasticsearch).  This allows us to run our own search engine for the files inside of gists that we are interested in.

We also have a script that will output several `.json` files that can be used to create visualizations such as [all the blocks](http://bl.ocks.org/enjalot/1d679f0322174b65d032) and the ones described in [this post](https://medium.com/@enjalot/searching-for-examples-2c0f75709c1a#.4fr5vuq7k).

##  Setup

### Config.js
First create a `config.js` file. You can copy `config.js.example` and replace the placeholders with a GitHub [application token](https://github.com/settings/applications/new). This token is important because it frees you from GitHub API rate limits you would encounter running these scripts without a token.

`config.js` is also the place to configure [Elasticsearch](https://www.elastic.co/products/elasticsearch) and the [RPC](https://en.wikipedia.org/wiki/Remote_procedure_call) server, if you plan to run them.

## Scraping

### List of users to scrape

There are several files related to users. The most important is `data/usables.csv`, a list of GitHub users that have at least 1 public gist. 
`data/usables.csv` is kept up-to-date manually via the process below. After each manual update, `data/usables.csv` is checked in to the [blockbuilder-search-index](https://github.com/enjalot/blockbuilder-search-index) repository.

Only run these scripts if you want to add a batch of users from a new source. It is also possible to manually edit `data/usables.csv` and add a new username to the end of the file.

[bl.ocksplorer.org](http://bl.ocksplorer.org) has a user list they maintain that can be downloaded from the [bl.ocksplorer.org form results](https://docs.google.com/spreadsheet/pub?key=0Al5UYaVoRpW3dE12bzRTVEp2RlJDQXdUYUFmODNiTHc&single=true&gid=0&output=csv) and is automatically pulled in by `combine-users.coffee`.
These users are combined with data exported from the [blockbuilder.org](blockbuilder.org) database of logged in users (found in `data/user-sources/blockbuilder-users.json`. These user data only contains publically available information from a user's GitHub profile.
`combine-users.coffee` produces the file `data/users-combined.csv`, which serves as the input to `validate-users.coffee` which then will query the GitHub API and make a list of everyone who has at least 1 public gist.   `validate-users.coffee` then saves that list to `data/usables.csv`.

### Gist metadata

First we query the [GitHub API for each user](https://developer.github.com/v3/gists/#list-a-users-gists) to obtain a list of gists that we would like to process.

```shell
# generate data/gist-meta.json, the list of all blocks
coffee gist-meta.coffee
# save to a different file
coffee gist-meta.coffee data/latest.json
# only get recent gists
coffee gist-meta.coffee data/latest.json 15min
# only get gists since a date in YYYY-MM-DDTHH:MM:SSZ format
coffee gist-meta.coffee data/latest.json 2015-02-14T00:00:00Z
```

`data/gist-meta.json` is kept up-to-date manually and checked in to the [blockbuilder-search-index](https://github.com/enjalot/blockbuilder-search-index) repository. When deployed, this code uses `data/gist-meta.json` to bootstrap the search index. After deployment, [cronjobs](https://en.wikipedia.org/wiki/Cron) will create `data/latest.json` every 15 minutes. Later in the pipeline, we use `data/latest.json` to index the gists in [Elasticsearch](https://www.elastic.co/products/elasticsearch)

### Gist content
The second step in the process is to download gist contents via raw urls and save them to disk in `data/gists-files/`. We selectively download files of certain types (see the code in `gist-content.coffee`) which saves us about 60% vs. cloning all of the gists.  

```shell
# default, will download all the files found in data/gist-meta.json
coffee gist-content.coffee
# specify file with list of gists
coffee gist-content data/latest.json
# skip existing files (saves time, might miss updates)
coffee gist-content data/gist-meta.json skip
```

### Flat data files
We can generate a series of JSON files that pull out interesting metadata from the downloaded gists.
```
coffee parse.coffee
```
This outputs to `data/` including `data/blocks*.json` and `data/apis.json` as well as `files-blocks.json`.

Note: there is code that will clone all the gists to `data/gist-clones/` but it needs some extra rate limiting before its robust.
As of 2/11/16 there are about 7k blocks, the `data/gist-files/` directory is about 1.1GB while `data/gist-clones/` ends up at 3GB.
Neither of these are an unreasonable amount. The advantage of cloning would be that future updates could be run by simply doing a git pull
and we would be syncing with higher fidelity. It's on the TODO list but not essential to the goal of having a reliable search indexing pipeline.

### Custom gallery JSON

I wanted a script that would take in a list of block URLS and give me a subset of the `blocks.json` formatted data. It currently depends on the blocks being part of the list, so anonymous blocks won't work right now.

```
coffee gallery.coffee data/unconf.csv data/out.json
```

## [Elasticsearch](https://www.elastic.co/products/elasticsearch)

Once you have a list of gists (either `data/gist-meta.json`, `data/latest.json` or otherwise) and you've downloaded the content to `data/gist-files/` you can index the gists to [Elasticsearch](https://www.elastic.co/products/elasticsearch):
```
coffee elasticsearch.coffee
# index from a specific file
coffee elasticsearch.coffee data/latest.json
```

I deploy this on a server with cronjobs, see the [example crontab](https://github.com/enjalot/blockbuilder-search-index/blob/master/deploy/crontab)

### RPC host

I made a very simple REST server that will listen for incoming gists to index them, or an id of a gist to delete from the index.
This is used to keep the index immediately up-to-date when a user saves or forks a gist from [blockbuilder.org](http://blockbuilder.org).
Currently the save/fork functionality will index if it sees that the gist is public, and it will delete if it sees that the gist is private. This way if you make a previously public gist private
and updated it via blockbuilder it will be removed from the search index.

I deploy it to the same server as [Elasticsearch](https://www.elastic.co/products/elasticsearch), and have security groups setup so that its not publicly accessible (only my blockbuilder server can access it)
```
node server.js
```
The server is deployed with this [startup script](https://github.com/enjalot/blockbuilder-search-index/blob/master/deploy/blockbuilder-search-index.conf)


### Mappings
The mappings used for elasticsearch can be found [here](https://gist.github.com/enjalot/a8fb0e18c960a37d1d18). I've been using the Sense app frome elasticsearch to configure and test my setup both locally and deployed. The default url for sense is `http://localhost:5601/app/sense`.

The `/blockbuilder` index is where all the blocks go, the `/bbindexer` index is where I log the results of each script run (`gist-meta.coffee` and `gist-content.coffee`) which is helpful
for keeping up with the status of the cron jobs.
