# qbtlib.sh
bash library to manipulate qbittorent via web api

## installation
it uses recursion, so you must `chmod +x` it before use

## usage

resume particular torrents  
`qbtlib.sh last | grep Отечественная | cut -f1 | bash qbtlib.sh resume`

`last` is runs slow for big lists, you may use `cache` instead. it contains `last`'s last output.
In other words `qbtlib.sh cache` is the same as `qbtlib.sh last`.

top countries from active torrent  
`qbtlib.sh active | cut -f1 | bash qbtlib.sh countries | qbtlib.sh top`

upload monitor  
`watch 'bash qbtlib.sh monitor | tail -n50'`

most connected peers  
`qbtlib.sh active | cut -f1 | qbtlib.sh connections | qbtlib.sh top`

their files  
`time qbtlib.sh active | cut -f1 | qbtlib.sh connections | qbtlib.sh rawtop | qbtlib.sh peerfiles`

hashes from top countries  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n3 | parallel --tag -k qbtlib.sh tcountries`

content path of active torrents by top 4 coutries  
`qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n4 | parallel qbtlib.sh tcountries | parallel -k --tag --colsep=$'\t' 'qbtlib.sh cpath {1}' | cut -f2- -d' ' | column -t -s$'\t'`
