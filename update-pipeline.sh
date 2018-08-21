# here is the log of a d3 blocks metadata update run
# this log assumes that:
#
#  1) we have already updated before, and only need to check since the last update date
#     (which in our case was ~20180120.  we'll get everything since 2018-01-19T00:00:00Z 
#      to be safe) 
#  2) we are not worried about validating that users have at least one
#
# note: 
#   each command shows a sample of what the terminal output 
#   should look like if command runs successfully


BLOCKBUILDER_SEARCH_INDEX_HOME="/Users/m/workspace/blockbuilder-search-index"
UPDATE_AFTER_TIMESTAMP="2018-03-14T00:00:00Z"

cd $BLOCKBUILDER_SEARCH_INDEX_HOME

coffee combine-users.coffee
# 205 users from blocks links in SO
# 468 users from blocks links in knight course
# 2594 users added from bb
# 200 added from manual list of users
# 39 users added from blocksplorer
# 3506 users total

#
# optionally get all blocks for new users 
# for all time
#
# TODO implement bash if else to check if 
# the file data/new.json exists
# if yes, run this command. if no, do nothing
#  
# coffee gist-meta.coffee data/new.json '' 'new-users'
# combining 3147 with 25277 existing blocks
# writing 28336 blocks to data/gist-meta.json
# writing 3147 to data/new.json

#
# fetch the metadata for all new gists
# for all known users from the github API
#
#
# TODO: inside gist-meta script handle case were github 
# API allocaton runs out before metadata is fetched for all users
# fixing this is required to run the whole pipeline in sequence, 
# in autonomous mode
#
coffee gist-meta.coffee data/latest-20180314-to-20180820.json $UPDATE_AFTER_TIMESTAMP
# x-ratelimit-remaining: 4652
# done with yonester, found 5 gists
# x-ratelimit-remaining: 4651
# x-ratelimit-remaining: undefined
# done with yifancui, found 34 gists
# x-ratelimit-remaining: undefined
# ...
# done with zzolo, found 0 gists
# done. number of new gists: 1965
# combining 1965 with 29327 existing blocks
# writing 29424 blocks to data/gist-meta.json
# writing 1965 to data/latest-after-20180314.json
# Elasticsearch DEBUG: 2018-08-21T12:58:48Z
#   starting request { method: 'POST',
#     path: '/bbindexer/scripts',
#     body:
#      { script: 'meta',
#        numBlocks: 1965,
#        filename: 'data/latest-after-20180314.json',
#        since: 1970-01-01T00:00:00.000Z,
#        ranAt: 2018-08-21T12:58:48.304Z },
#     query: {} }
#
#
# Elasticsearch TRACE: 2018-08-21T12:58:49Z
#   -> POST http://localhost:9200/bbindexer/scripts
#   {
#     "script": "meta",
#     "numBlocks": 1965,
#     "filename": "data/latest-after-20180314.json",
#     "since": "1970-01-01T00:00:00.000Z",
#     "ranAt": "2018-08-21T12:58:48.304Z"
#   }
#   <- 201
#   {
#     "_index": "bbindexer",
#     "_type": "scripts",
#     "_id": "AWVckPawo8z7fxr9sXXM",
#     "_version": 1,
#     "_shards": {
#       "total": 2,
#       "successful": 1,
#       "failed": 0
#     },
#     "created": true
#   }
#
# Elasticsearch DEBUG: 2018-08-21T12:58:49Z
#   Request complete
#
# indexed

#
# let's clone the gists we just found
#
coffee gist-cloner.coffee data/latest-20180314-to-20180820.json
# From https://gist.github.com/cec274f418b8675efaead3a56a5b324b
#  * branch            master     -> FETCH_HEAD
# Already up-to-date.
# cec274f418b8675efaead3a56a5b324b yonicd 0 From https://gist.github.com/cec274f418b8675efaead3a56a5b324b
#  * branch            master     -> FETCH_HEAD
#
# From https://gist.github.com/4bc59fca901388ebe4905bdb19af1567
#  * branch            master     -> FETCH_HEAD
# Already up-to-date.
# 4bc59fca901388ebe4905bdb19af1567 yonicd 0 From https://gist.github.com/4bc59fca901388ebe4905bdb19af1567
#  * branch            master     -> FETCH_HEAD
#
# done writing files
# Elasticsearch DEBUG: 2018-08-21T13:14:54Z
#   starting request { method: 'POST',
#     path: '/bbindexer/scripts',
#     body:
#      { script: 'content',
#        timeouts: [],
#        filename: 'data/latest-20180314-to-20180820.json',
#        ranAt: 2018-08-21T13:14:54.063Z },
#     query: {} }
#
#
# Elasticsearch TRACE: 2018-08-21T13:14:54Z
#   -> POST http://localhost:9200/bbindexer/scripts
#   {
#     "script": "content",
#     "timeouts": [],
#     "filename": "data/latest-20180314-to-20180820.json",
#     "ranAt": "2018-08-21T13:14:54.063Z"
#   }
#   <- 201
#   {
#     "_index": "bbindexer",
#     "_type": "scripts",
#     "_id": "AWVcn7EAo8z7fxr9sXXS",
#     "_version": 1,
#     "_shards": {
#       "total": 2,
#       "successful": 1,
#       "failed": 0
#     },
#     "created": true
#   }
#
# Elasticsearch DEBUG: 2018-08-21T13:14:54Z
#   Request complete
#
# indexed

coffee parse.coffee
# 29419 'a488e022362571a9e1187985df7f47a4'
# 29420 '8d331f9b5c7dd57908de0db3439ab7ab'
# 29421 'd1dbded3fe2c8cb94b207904c7c4c73d'
# 29422 '5b7d24613149e60867c2bf6fe097c587'
# 29423 '492182b66a0d1a3dd5513ff5b71c900c'
# 29424 '056046c1f83e3926484bd2e21847341e'
# done
# skipped 0 missing files
# wrote 10445 API blocks
# wrote 11522 Color blocks
# wrote 117533 Files blocks
# wrote 29424 total blocks

cd data/parsed
pwd
# /Users/m/workspace/blockbuilder-search-index/data/parsed

#
# tada, we have some fresh blocks metadata files
#
ls -lAFh
# total 286816
# -rw-r--r--@ 1 m  staff   6.0K Mar 16 18:10 .DS_Store
# -rw-r--r--  1 m  staff     2B Aug 21 06:29 apis.json
# -rw-r--r--  1 m  staff   3.2M Aug 21 06:29 blocks-api.json
# -rw-r--r--  1 m  staff   2.2M Aug 21 06:29 blocks-colors-min.json
# -rw-r--r--  1 m  staff   4.2M Aug 21 06:29 blocks-colors.json
# -rw-r--r--  1 m  staff   5.9M Aug 21 06:29 blocks-min.json
# -rw-r--r--  1 m  staff    76M Aug 21 06:29 blocks.json
# -rw-r--r--  1 m  staff     2B Aug 21 06:29 colors.json
# -rw-r--r--  1 m  staff    45M Aug 21 06:29 files-blocks.json
# -rw-r--r--  1 m  staff    10B Aug 21 06:29 libs.csv
# -rw-r--r--  1 m  staff    13B Aug 21 06:29 modules.csv
# -rw-r--r--  1 m  staff   3.6M Aug 14  2017 readme-blocks-graph.json

#
# now let's call another shell script to generate the 
# blocks graph metadata
#
sh update-pipeline-blocks-graph.sh
