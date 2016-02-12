## Download and parse blocks for search
This repo is a combination of utility scripts and services that support the continuous scraping and indexing
of public blocks. It powers [Blockbuilder](http://blockbuilder.org)'s [search page](http://blockbuilder.org/search).

[Blocks](https://bl.ocks.org) are stored as GitHub [gists](https://gist.github.com), which are essentially mini git repositories.
Given a list of users we can query the [GitHub API](https://developer.github.com/v3/gists/) for the latest public gists each of those users has updated or created.
We can then filter those gists to just those which have an `index.html` file (the main prerequisite for a block to be rendered). Once we have a list of gists
from the API we can download their files to disk for further processing. The main thrust here is to index some of those files in Elasticsearch so we can provide
a search engine over them.

We also have a script that will output several json files that can be used to make visualizations such as [all the blocks](http://bl.ocks.org/enjalot/1d679f0322174b65d032).

##  Setup

### Config.js
You will need to create `config.js` before running any of the below commands, you can copy `config.js.example` and replace the placeholders with [application tokens](https://github.com/settings/applications/new). This token is important because otherwise you will quickly run into rate limits from the GitHub API running the below scripts.
This is also where you will configure Elasticsearch and the RPC server if you are running them.

## Scraping

### List of users to scrape

There are several files related to users. The most important is the file listing users that have at least 1 public gist: `data/usables.csv`.
This file is kept up-to-date manually and checked in, via the process below. You don't need to run any of this unless you want to add a new source of users, the easiest would be to just add a username to the end of `data/usables.csv`.

[bl.ocksplorer.org](http://bl.ocksplorer.org) has a user list they maintain that can be downloaded from the [bl.ocksplorer.org form results](https://docs.google.com/spreadsheet/pub?key=0Al5UYaVoRpW3dE12bzRTVEp2RlJDQXdUYUFmODNiTHc&single=true&gid=0&output=csv) and is automatically pulled in by `combine-users.coffee`.
These users are combined with a dump from the blockbuilder.org database of logged in users (found in `data/mongo-users.json`, it only contains public information found on a users GitHub profile).
The output of `combine-users.coffee` is `data/users-combined.csv`, which serves as the input to `users.coffee` which will query the GitHub API and make a list of everyone who has at least 1 public gist and save that list to `data/usables.csv`.

### Gist metadata

The first step in the process is to obtain a list of gists we would like to process. We do this by querying the [GitHub API for each user](https://developer.github.com/v3/gists/#list-a-users-gists).

```
# generate data/gist-meta.json, the list of all blocks
coffee gist-meta.coffee
# save to a different file
coffee gist-meta.coffee data/latest.json
# only get recent gists
coffee gist-meta.coffee data/latest.json 15min
# only get gists since a date in YYYY-MM-DDTHH:MM:SSZ format
coffee gist-meta.coffee data/latest.json 2015-02-14T00:00:00Z
```

The `data/gist-meta.json` file is checked into the repository for now, and is also kept up-to-date manually. The deployment of this code uses it as a way to bootstrap the search index, after which cronjobs will create `data/latest.json` every 15 minutes for the next steps of the pipeline.


### Gist content
The second step in the process is to download gist contents via raw urls and save them to disk in `data/gists-files/`. We selectively download files of certain types (see the code in `gist-content.coffee`) which saves us about 60% vs. cloning all of the gists.
```
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

## Elasticsearch

Once you have a list of gists (either `data/gist-meta.json`, `data/latest.json` or otherwise) and you've downloaded the content to `data/gist-files/` you can index the gists to Elasticsearch:
```
coffee elasticsearch.coffee
# index from a specific file
coffee elasticsearch.coffee data/latest.json
```

### RPC host

I made a very simple REST server that will listen for incoming gists to index them, or an id of a gist to delete from the index.
This is used to keep the index immediately up-to-date when a user saves or forks a gist from [blockbuilder.org](http://blockbuilder.org).
Currently the save/fork functionality will index if it sees that the gist is public, and it will delete if it sees that the gist is private. This way if you make a previously public gist private
and updated it via blockbuilder it will be removed from the search index.

I deploy it to the same server as Elasticsearch, and have security groups setup so that its not publicly accessible (only my blockbuilder server can access it)
```
node server.js
```

### Mappings
The mappings used for elasticsearch are found below. I've been using the Sense app frome elasticsearch to configure and test my setup both locally and deployed. The default url for sense is `http://localhost:5601/app/sense`.

The `/blockbuilder` index is where all the blocks go, the `/bbindexer` index is where I log the results of each script run (`gist-meta.coffee` and `gist-content.coffee`) which is helpful
for keeping up with the status of the cron jobs.

```
DELETE /blockbuilder

PUT /blockbuilder
{
  "mappings": {
    "blocks": {
      "properties": {
        "userId": {
          "type": "string",
          "index": "not_analyzed"
        },
        "created_at": {
          "type": "date"
        },
        "updated_at": {
          "type": "date"
        },
        "api": {
          "type": "string",
          "index": "not_analyzed"
        },
        "colors": {
          "type": "string",
          "index": "not_analyzed"
        },
        "filenames": {
          "type": "string",
          "index": "not_analyzed"
        }
      }
    }
  }
}

GET /blockbuilder/blocks/_search
{
  "query": {
    "match": {
      "description": "dance"
    }
  }
}

GET /blockbuilder/blocks/_search
{
  "aggs": {
    "all_api": {
      "terms": { "field": "api" }
    }
  }
}

GET /blockbuilder/blocks/_search
{
  "aggs": {
    "all_colors": {
      "terms": { "field": "colors" }
    }
  }
}

GET /blockbuilder/blocks/_search
{
  "aggs": {
    "all_colors": {
      "terms": { "field": "filenames" }
    }
  }
}

GET /blockbuilder/blocks/_search
{
  "query": {
    "match_all": {}
  },
  "sort": { "updated_at":{ "order": "desc" }}
}

DELETE /bbindexer

PUT /bbindexer
{
  "mappings": {
    "blocks": {
      "properties": {
        "script": {
          "type": "string",
          "index": "not_analyzed"
        },
        "filename": {
          "type": "string",
          "index": "not_analyzed"
        },
        "since": {
          "type": "date"
        },
        "ranAt": {
          "type": "date"
        }
      }
    }
  }
}

GET /bbindexer/scripts/_search
{
  "query": {
    "match_all": {}
  },
  "sort": { "ranAt":{ "order": "desc" }}
}

GET /bbindexer/scripts/_search
{
  "query": {
    "match": { "script": "meta"}
  },
  "sort": { "ranAt":{ "order": "desc" }}
}
```
