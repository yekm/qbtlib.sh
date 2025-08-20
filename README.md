## qbtlib.sh
bash library to manipulate qbittorent via web api  
or  
practical introduction to gnu parallel and jq. `jq` is used for filtering and converting
json data from qbittorrent to TSV format on which simple tools like `head` and `grep` can be used.


### installation
`sudo ln -sfrt /bin ./qbtlib.sh`

dependencies: bash, curl, jq, gnu parallel, awk, util-linux, coreutils


### usage

First command you should run is `qbtlib.sh last`. It stores json answer from qbt in zstd-compressed
file in `/tmp/qbtlib.sh.cache_datetime.zst`. Last json cache can later be viewed in tsv format by invoking
`qbtlib.sh cache` or in json format with `cache.js` command. For the most commands the input and output
format is `tsv` in order to be able to use simple commands like `cut`, `grep`, `sed` and many others to
manipulate the list of torrents and/or their metadata like file list, trackers, peers and maybe others.

`export QBT_HOST=whatever:port`, default is `localhost:8283`

get torrent list sorted by added_on column  
`qbtlib.sh last`

output format is tab separated `hash` `category`, `content_path` and `percent done`
(you may use `qbtlib.sh tinfo.js` to customize output via custom jq query)

resume some torrents  
`qbtlib.sh last | grep some | cut -f1 | qbtlib.sh resume`

`last` is slow for big lists (5 sec for 30k torrents), you may use `cache` instead:
it contains `last`'s last output (stored compressed in /tmp).

list complete torrents  
`qbtlib.sh cache |grep '100$' | less`

list incomplete torrents  
`qbtlib.sh cache |grep -v '100$' | less`

set category for last 40 added torrents  
`qbtlib.sh cache | tail -n40 | cut -f1 | qbtlib.sh set_category newcategory`

move last 40 added torrents  
`qbtlib.sh cache | tail -n40 | cut -f1 | qbtlib.sh set_location /new/location`

display app preferences as table  
`qbtlib.sh pref`

edit preferences  
```
qbtlib.sh pref.js | tee /tmp/pref.json
vim /tmp/pref.json
qbtlib.sh pref.js /tmp/pref.json
```
or automagically filter json with sed:  
`qbtlib.sh pref_sed 's/"max_connec": .*/"max_connec": 512,/'`

files for last 5 added torrents  
`qbtlib.sh cache | tail -n5 | cut -f1 | parallel -k qbtlib.sh tfiles | cut -f1- | column -t -s$'\t' -N id,file,prio,progress,sizeGB`

set high priority for files containig word `Season1` for last torrent  
`qbtlib.sh cache | tail -n1 | cut -f1 | parallel 'qbtlib.sh tfiles {} | grep Season1 | cut -f1 | qbtlib.sh setfpriority {} 6'`  
0 - Do not download, 1 - Normal priority, 6 - High priority, 7 - Maximal priority

top active categories  
`qbtlib.sh active | cut -f2 | qbtlib.sh top`

top countries from active torrent  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh top`

number of peers from all coutries excluding one top country  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh top | head -n-1 | awk '{print $1}' | paste -sd+  | bc`

upload monitor  
`watch 'qbtlib.sh monitor | tail -n50'`

most connected peers  
`qbtlib.sh active | cut -f1 | qbtlib.sh connections | cut -f2 | qbtlib.sh top`

content paths used by most connected peer  
`qbtlib.sh active | cut -f1 | qbtlib.sh connections | cut -f2 | qbtlib.sh rawtop | tail -n1 | qbtlib.sh peerpaths`

hashes from top countries  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n3 | parallel -k qbtlib.sh tcountries`

content path of active torrents by top 4 coutries  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n4 | parallel -k qbtlib.sh tcountries | parallel -k --tag --colsep=$'\t' 'echo {1} | qbtlib.sh cpath' | cut -f2- -d' ' | column -t -s$'\t'`

show last one torrent pieces (`.` - Not downloaded yet, `v` - Now downloading, `*` - Already downloaded)  
`qbtlib.sh cache1 | tail -n1 | parallel qbtlib.sh pieces`

recheck N torrents at a time  
`qbtlib.sh cache | cut -f1 | qbtlib.sh slowcheck N`

add torrents to qbt  
`parallel qbtlib.sh add ::: *.torrent`

delete torrents with their files  
`qbtlib.sh last | grep some | cut -f1 | qbtlib.sh delete deletefilestoo`

qbt docs: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)#torrent-management
https://github.com/qbittorrent/wiki/blob/master/WebUI-API-(qBittorrent-5.0).md


## rtrckr.sh

Tool for interfacing with rutracker.org. Requires `rtrkr_curl.sh` to be available
in PATH. `rtrkr_curl.sh` can be obtained in DevTools network window by seleceting
`Copy as CURL` in the relevant menu item. After creating it must be edited to
accept url as first parameter (also you can specify a `--proxy` parameter there).
See a bottom of `rtrckr.sh` for an example.

Search function relies on plain text database in TSV format. This database can be
obtained by converting xml dump of all torrents (5591249 topic id) by running
`rtrckr.sh xml2tsv`

`rtrckr.sh grep` is the main command which finds words in tsv file. Equivalent to
`cat $tsv | grep arg1 | grep arg2 | grep arg3 ...` (args is actually in reverse
order but whatever)

`rtrckr.sh find` same as grep but output is somewhat filtered. Sorted by size,
outputs only certain columns (kinda unstable, but id should always be the first column)

`rtrckr.sh download` download torrent file into /tmp and add it to a qbt via
`qbtlib.sh add`

`rtrckr.sh frompage` lists all torrent ids from a certain webpage. Useful to
download a list of torrents from some forum topic.

`rtrckr.sh xml2tsv` converts xml dump to a tsv database

`rtrckr.sh curl` invokes rtrkr_curl.sh

### usage

find all torrents with `ubuntu` in title or forum name  
`rtrckr.sh find ubuntu`

download all relevant torrents to a certain directory  
`rtrckr.sh find ubuntu bdremux | cut -f1 | parallel -j4 'rtrckr.sh download {} -F savepath=/mnt/all/film -F category=film -F tags=rtrckr -F paused=false'`

download all torrents mentioned on certain page  
`rtrckr.sh frompage https://rutracker.org/forum/viewtopic.php?t=6012098 | parallel -j4 'rtrckr.sh download {} -F savepath=/mnt/all/mult/FilmScan -F category=mult/fscan -F paused=false'`

forums stats  
`rtrckr.sh grep | cut -f7 | sed 's/ - .*//' | sort -u | parallel --tag 'rtrckr.sh grep {} | cut -f3 | qbtlib.sh sum | qbtlib.sh bytes' | sort -t$'\t' -k2 -n | qbtlib.sh table`


## utils

Assortment of useful utils: [utils.md]


## todo

* dynamic disk throttling via maximum number of connections  
  a lot of fast peers present during the day,
  a lot of connections puts unnecessary pressure to disks.
  PID controller will do fine here.

* qbt version detecrion. After v5 release they cnahged `resume` to `start` (wtf!?).

* rewrite all `paste -sd|` to `parallel --pipe -n1234 'paste -sd|' | parallel ... --data={}...`


## autogenerated help

```
$ qbtlib.sh help
cache               ... print cached `qbtlib.sh last`
cache1              ... print only hashes from cached `qbtlib.sh last`
cache.js            ... print cached `qbtlib.sh last` in json
cache.custom        ... print cached `qbtlib.sh last` with custom jq selector columns in arg1, like .hash, .category, .content_path, .progress*100
last                ... list torrents sotred by `added_on`
last.r              ... list torrents sotred by `ratio`
active              ... list torrents sotred by `added_on` filtered by `active`
active1             ... list only hashes sotred by `added_on` filtered by `active`
active.js           ... list torrents sotred by `added_on` filtered by `active` in json
info.js             ... list torrents sotred by `added_on` filtered by `active` in json
tinfo.js            h|p torrent info in json
tinfo               h|p torrent info
tinfo.my            h|p torrent info in custom format
texists             ... <arg1> check if torrent with hash arg1 exists
resume              h|p resume torrents
stop                h|p stop torrents
recheck             h|p recheck torrents
slowcheck           h|. [arg1=2] recheck torrents `arg1` at a time, default 2
add                 ... <filename> [args] add torrent. optional args -F savepath= -F category= -F tags= -F paused=true
delete              h|p [`arg1`] delete torrents, arg1 can be "deletefilestoo"
tfiles              ... <hash> list files by one `hash` (name, priority, progress, size in GiB, name)
tfiles.js           ... <hash> list files by one `hash` in json
setfpriority        id|p <arg1> <arg2> set pieces priority to `arg2` (0,1,6,7) for torrent with hash `arg1`
pieces              ... <hash> show torrent pieces
cpath               h|p list content path by hashes
get_location        h|p get torrent locations
set_location        h|p <arg1> moves torrents to a new location `arg1`
sed_location        h|p <arg1> moves torrents to a new location `echo old_location | sed arg1`
set_category        h|p <arg1> set cetegory to `<arg1>` on torrents
qtop                h|p move torrents on top of the queue
qbottom             h|p move torrents on bottom of the queue
tracker1            h|. list trackers
trackers            h|. list trackers
tracker_add         h|. <tracker_url> add tracker url to torrents
peers               h|. list peers on a hash sorted by country, like in webui
peerhashes          ip| list hashes on a peer
peerpaths           ip| list content paths by peer
connections         h|. list peers on a hash
connections2        h|. list peers on a hash sorted by country
countries           h|. list peer countries by hash
icountries          h|. list peer countries by hash with --tag
tcountries          ... <country> hashes by `country`. (active list icountries hashes grepped by `country`
monitor             ... list uploading torrent to sorted by `upspeed`
monitor_dl          ... list downloading torrent to sorted by `dlspeed`
kick_stalled_dl     ... [delay] deprioritise incomplete stalled downloading torrents
togglespeed         ... toggle alternative speed limits
gspeed              ... [ul] [dl] get/set global up/dl limits in MiB/s
speednow            ... current speed ul dl
sl                  ... speed limits mode
pref.js             ... [arg1] set new preferences from file `arg1` if exists. display preferences in json.
pref_sed            ... <arg1> set new preferences filtered by sed arg1
pref                ... app preferences
stat                ... display overall statistics
stat.png            ... generate ratio-size scatter plot
log                 ... display log
influx              ... store number of active torrents and connections, and ul dl speed in influxdb
appendspeedhistory  ... apeend writes current date and speed in /tmp/qbtlib_speedhistory.log
plotspeed           ... plot saved speed history with gnuplot
ss                  ... cat /tmp/qbtlib_speedhistory.log
sparkhistory        ... ▇▅▃█▆
top                 .|. actually bottom
rawtop              .|. same as bove but without first column of numbers
table               .|. [] format tsv as table
js.table            .|. [] format json object key-values as table
_sum                .|. add up all numbers
sum                 .|. add up a lot of numbers
bytes               .|. pretty print amount of bytes
bsum                .|. add up a lot of numbers, pretty print as bytes

examples:
qbtlib.sh pref_sed 's/"max_connec": .*/"max_connec": 1024,/'
qbtlib.sh cache | grep some | cut -f1 | qbtlib.sh resume
qbtlib.sh cache | grep '100$' | less
qbtlib.sh cache | grep -v '100$' | less
qbtlib.sh cache | grep some | cut -f1 | qbtlib.sh set_category newcategory
qbtlib.sh cache | grep some | cut -f1 | qbtlib.sh set_location /new/location
qbtlib.sh active1 | qbtlib.sh countries | qbtlib.sh top
qbtlib.sh tcountries korea | cut -f1 | qbtlib.sh cpath
qbtlib.sh cache1 | tail -n5 | parallel -k qbtlib.sh tfiles | cut -f1- | column -t -s$'\t' -N id,file,progress,sizeGB
watch 'qbtlib.sh monitor | tail -n50'
qbtlib.sh active | cut -f1 | qbtlib.sh connections | qbtlib.sh top
qbtlib.sh active1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n4 | parallel -k qbtlib.sh tcountries | parallel -k --tag --colsep=$'\t' 'echo {1} | qbtlib.sh cpath' | cut -f2- -d' ' | column -t -s$'\t'
qbtlib.sh cache1 | tail -n1 | parallel 'qbtlib.sh tfiles {} | grep Season1 | cut -f1 | qbtlib.sh setfpriority {} 6'
too long list of hashes | parallel --pipe -n1000 -j1 qbtlib.sh cmd
qbtlib.sh cache.js | jq -r '.[] | select(.state == "stoppedDL") | .hash'

```
