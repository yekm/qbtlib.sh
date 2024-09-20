# qbtlib.sh
bash library to manipulate qbittorent via web api  
or  
practical introduction to gnu parallel and jq. `jq` is used for filtering and converting
json data from qbittorrent to TSV format on which simple tools like `head` and `grep` can be used.


## installation
`sudo ln -sfrt /bin ./qbtlib.sh`

dependencies: bash, curl, jq, gnu parallel, awk, util-linux, coreutils


## usage

`export QBT_HOST=whatever:port`

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

files for last 5 added torrents  
`qbtlib.sh cache | tail -n5 | cut -f1 | parallel -k qbtlib.sh tfiles | cut -f1- | column -t -s$'\t' -N file,progress,sizeGB`

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

speed history using `spark`  
```
$ qbtlib.sh sparkhistory
42 max    / min    16:10                                      14:51
ul  62.501/ 55.300 ▃▄▆▅▂▅▆▄▅▆▆█▅▅▁▅▇▆▅▄▃▂▃▇▇▅▃█▆▅▂▅▅▆▅▆▄▅▆▆▆▅ 15:27 
dl   0.000/  0.000 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ 15:27 
```

recheck N torrents at a time  
`qbtlib.sh cache | cut -f1 | qbtlib.sh slowcheck N`

qbt docs: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)#torrent-management

```
$ qbtlib.sh help
cache         ... print cached `qbtlib.sh last`
cache1        ... print only hashes from cached `qbtlib.sh last`
last          ... list torrents sotred by `added_on`
active        ... list torrents sotred by `added_on` filtered by `active`
active1       ... list only hashes sotred by `added_on` filtered by `active`
active.js     ... list torrents sotred by `added_on` filtered by `active` in json
tinfo.js      h|p torrent info in json
resume        h|p resume torrents
pause         h|p pause torrents
recheck       h|p recheck torrents
slowcheck     h|. [arg1=2] recheck torrents `arg1` at a time, default 2
tfiles        ... <hash> list files by one `hash` (name, progress, size in GiB)
tfiles.js     ... <hash> list files by one `hash` in json
cpath         h|p list content path by hashes
set_location  h|p <arg1> moves torrents to a new location `arg1`
set_category  h|p <arg1> set cetegory to `<arg1>` on torrents
qtop          h|p move torrents on top of the queue
qbottom       h|p move torrents on bottom of the queue
peerhashes    ip| list hashes on a peer
peerpaths     ip| list content paths by peer
connections   h|. list peers on a hash
connections2  h|. list peers on a hash sorted by country
countries     h|. list peer countries by hash
icountries    h|. list peer countries by hash with --tag
tcountries    ... <country> hashes by `country`. (active list icountries hashes grepped by `country`
monitor       ... list uploading torrent to sorted by `upspeed`
monitor_dl    ... list downloading torrent to sorted by `dlspeed`
togglespeed   ... toggle alternative speed limits
gspeed        ... [ul] [dl] get/set global up/dl limits in MiB
speednow      ... current speed ul dl
top           ... actually bottom
rawtop        ... same as bove but without first column of numbers
influx        ... store number of active torrents and connections, and ul dl speed in influxdb
speedhistory  ... <EULA> apeend writes current date and speed in /tmp/qbtlib_speedhistory.log
ss            ... cat /tmp/qbtlib_speedhistory.log
sparkhistory  ... ▇▅▃█▆

examples:
qbtlib.sh cache | grep some | cut -f1 | qbtlib.sh resume
qbtlib.sh cache | grep '100$' | less
qbtlib.sh cache | grep -v '100$' | less
qbtlib.sh cache | grep some | cut -f1 | qbtlib.sh set_category newcategory
qbtlib.sh cache | grep some | cut -f1 | qbtlib.sh set_location /new/location
qbtlib.sh active1 | qbtlib.sh countries | qbtlib.sh top
qbtlib.sh tcountries korea | cut -f1 | qbtlib.sh cpath
qbtlib.sh cache1 | tail -n5 | parallel -k qbtlib.sh tfiles | cut -f1- | column -t -s$'\t' -N file,progress,sizeGB
watch 'qbtlib.sh monitor | tail -n50'
qbtlib.sh active | cut -f1 | qbtlib.sh connections | qbtlib.sh top
qbtlib.sh active1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n4 | parallel -k qbtlib.sh tcountries | parallel -k --tag --colsep=$'\t' 'echo {1} | qbtlib.sh cpath' | cut -f2- -d' ' | column -t -s$'\t'
```

## fun

Total created processes:
```
# content path of active torrents by top 4 coutries
$ time strace -e none -ff bash -c "qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n4 | parallel qbtlib.sh tcountries | parallel -k --tag --colsep=$'\t' 'qbtlib.sh cpath {1}' | cut -f2- -d' ' | column -t -s$'\t' " |& grep Process | grep attached | wc -l
5119

real    0m9.924s
user    0m16.649s
sys     0m19.255s

# files from top 10 peers
$ time strace -e none -ff bash -c "qbtlib.sh active | cut -f1 | qbtlib.sh connections | qbtlib.sh rawtop | tail -n10 | qbtlib.sh peerfiles" |& grep Process | grep attached | wc -l
11121

real    0m24.237s
user    0m39.619s
sys     0m53.063s

```
