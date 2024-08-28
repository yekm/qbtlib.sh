# qbtlib.sh
bash library to manipulate qbittorent via web api


## installation
`cp` and `cmof +x` somewhere in PATH. `chmod +x` is a must because it uses recursion

dependencies: bash, curl, jq, gnu parallel, awk, util-linux, coreutils


## usage

`export QBT_HOST=whatever:port`

get torrent list sorted by added_on column  
`qbtlib.sh last`

output format is tab separated `hash` `category`, `content_path` and `percent done`

resume some torrents  
`qbtlib.sh last | grep some | cut -f1 | qbtlib.sh resume`

`last` is runs slow for big lists, you may use `cache` instead. it contains `last`'s last output.
In other words `qbtlib.sh cache` is the same as `qbtlib.sh last`.

set category for last 40 added torrents  
`qbtlib.sh cache | tail -n40 | cut -f1 | qbtlib.sh set_category newcategory`

move last 40 added torrents  
`qbtlib.sh cache | tail -n40 | cut -f1 | qbtlib.sh set_location /new/location`

files for last 5 added torrents  
`qbtlib.sh cache | tail -n5 | parallel --tag -k 'qbtlib.sh tfiles {1}' | cut -f3- -d$'\t' | column -t -s$'\t'  -N name,file,done,sizeGB`

top active categories  
`qbtlib.sh active | cut -f2 | qbtlib.sh top`

top countries from active torrent  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh top`

number of peers from all coutries excluding one top country  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh top | head -n-1 | awk '{print $1}' | paste -sd+  | bc`

upload monitor  
`watch 'qbtlib.sh monitor | tail -n50'`

most connected peers  
`qbtlib.sh active | cut -f1 | qbtlib.sh connections | qbtlib.sh top`

their files (content path)  
`qbtlib.sh active | cut -f1 | qbtlib.sh connections | qbtlib.sh rawtop | qbtlib.sh peerfiles`

hashes from top countries  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n3 | parallel --tag -k qbtlib.sh tcountries`

content path of active torrents by top 4 coutries  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n4 | parallel qbtlib.sh tcountries | parallel -k --tag --colsep=$'\t' 'qbtlib.sh cpath {1}' | cut -f2- -d' ' | column -t -s$'\t'`


speed history using `spark`
$ qbtlib.sh sparkhistory
42 max    / min    16:10                                      14:51
ul  62.501/ 55.300 ▃▄▆▅▂▅▆▄▅▆▆█▅▅▁▅▇▆▅▄▃▂▃▇▇▅▃█▆▅▂▅▅▆▅▆▄▅▆▆▆▅ 15:27 
dl   0.000/  0.000 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ 15:27 


qbt docs: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)#torrent-management


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
