# usage:

# resume particular torrents
# bash qbtlib.sh last | grep Отечественная | cut -f1 | bash qbtlib.sh resume

# top countries from active torrent
# bash qbtlib.sh active | cut -f1 | bash qbtlib.sh countries | sort | uniq -c | sort -n

# upload monitor
# watch 'bash qbtlib.sh monitor | tail -n50'

# most connected peers:
# qbtlib.sh active | cut -f1 | qbtlib.sh connections | sort | uniq -c | sort -n

# their files:
# time qbtlib.sh active | cut -f1 | qbtlib.sh connections | sort | uniq -c | sort -n | rev | cut -f1 -d' ' | rev | qbtlib.sh peerfiles

# hashes from top countries:
# qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n3 | parallel --tag -k qbtlib.sh tcountries

# content path of active torrents by top 4 coutries
# qbtlib.sh active | cut -f1 | qbtlib.sh countries | qbtlib.sh rawtop | tail -n4 | parallel qbtlib.sh tcountries | parallel -k --tag --colsep=$'\t' 'qbtlib.sh cpath {1}' | cut -f2- -d' ' | column -t -s$'\t'

export PATH=$BASH_SOURCE:$PATH

tmp=/tmp/qbtlib.sh.cache_$(date +%F_%R).zst

_apicall() {
	s=--silent
	#s=--verbose
	#set -vx
	curl $s \
		http://${QBT_HOST:-localhost:8283}/api/v2/$1/$2 \
		"${@:3}"
	#set +vx
}

torrents() {
	_apicall torrents $@
}

sync() {
	_apicall sync $@
}

transfer() {
	_apicall transfer $@
}

peerhashes() {
	qbtlib.sh active | cut -f1 | parallel --tag 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .ip"' | grep -F -w $1
}
peerfiles() {
	peerhashes $1 | cut -f1 | parallel qbtlib.sh cpath
}

export -f _apicall torrents sync peerhashes peerfiles



case $1 in
cache)
	cat $(ls -1t /tmp/qbtlib.sh.cache_* | head -n1) | zstdmt -d
	;;
last)
	torrents info -G --data "sort=added_on" | \
		jq -r '[ .hash, .category, .content_path ] | @tsv' | \
		zstdmt --adapt | tee $tmp | zstdmt -d
	;;
tfiles)
	torrents files -G \
		--data "hash=$2" | \
		jq -r '.[] | [ .name, .progress*100, .size/1024/1024/1024 ] | @tsv' | column -t -s$'\t'
	;;
cpath)
	torrents info -G \
		--data "hashes=$2" | \
		jq -r '.[] | .content_path'
	;;
active)
	torrents info -G \
		--data "sort=added_on" \
		--data "filter=active" | \
		jq -r '.[] | [ .hash, .category, .content_path ] | @tsv'
	;;
active.js)
	torrents info -G \
		--data "sort=added_on" \
		--data "filter=active" | \
		jq
	;;
resume)
	hashes=$(paste -sd\|)
	torrents resume -X POST --data "hashes=$hashes"
	;;
recheck)
	hashes=$(paste -sd\|)
	torrents recheck -X POST --data "hashes=$hashes"
	;;
set_location)
	[ -z "$1" ] && echo specify location as first arg && exit -1
	hashes=$(paste -sd\|)
	torrents setLocation -X POST --data "hashes=$hashes" --data "location=$1"
	;;
peerhashes)
	parallel peerhashes
	;;
connections)
	parallel 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .ip"'
	;;
peerfiles)
	parallel --tag -k peerfiles
	;;

# "peers_country" by hashes
countries)
	parallel -k 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .country"'
	;;

# "hash peers_country" by hashes
icountries)
	parallel -k --tag 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .country"'
	;;

# "hash" by coutry
tcountries)
	qbtlib.sh active | cut -f1 | qbtlib.sh icountries | grep "$2" | rev | uniq -f1 | rev
	;;

# jq's floor should be embedded in an arrray.
# echo '{"mass": 188.72, "shit": 100}' | jq ' [ [.mass|floor] , .shit ] | flatten'
# looks ugly
monitor)
	torrents info -G \
		--data "sort=upspeed" \
		--data "filter=active" | \
		jq -r '.[] | [ .category, .name, .upspeed/1024/1024, .progress*100 ] | @tsv' | \
		column --table -o' ' -C name=category,width=1,strictwidth,trunc -C name=name,width=10,strictwidth -C name=up,width=1,strictwidth -C name=compl,width=1,strictwidth,trunc -T 0 -R 3,4 -m -s$'\t'
	echo
	transfer info | \
		jq -r '[ .connection_status, .dht_nodes, .dl_info_speed/1024/1204, .up_info_speed/1024/1024, ( .dl_info_speed + .up_info_speed )/1024/1024 ] | @tsv' | \
		column --table -N status,dhtnodes,dl,up,total -s$'\t'
	;;
monitor_dl)
	torrents info -G \
		--data "sort=dlspeed" \
		--data "filter=active" | \
		jq -r '.[] | [ .category, .name, .dlspeed/1024/1024, .progress*100 ] | @tsv' | \
		column --table -N category,name,upspeed,completed -s$'\t'
	echo
	transfer info | \
		jq -r '[ .connection_status, .dht_nodes, .dl_info_speed/1024/1204, .up_info_speed/1024/1024, ( .dl_info_speed + .up_info_speed )/1024/1024 ] | @tsv' | \
		column --table -N status,dhtnodes,dl,up,total -s$'\t'
	;;

top)
	sort | uniq -c | sort -n # without -r it's actually a `bottom`
	;;
rawtop)
	qbtlib.sh top | sed 's/ *[0-9]* //'
	;;
*)
	echo no such command
	exit -1
	;;
esac

set +vx
