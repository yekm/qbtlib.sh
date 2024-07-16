#!/bin/bash

export PATH=$BASH_SOURCE:$PATH

tmp=/tmp/qbtlib.sh.cache_$(date +%F_%R).zst

export QBT_HOST=${QBT_HOST:-localhost:8283}

_apicall() {
	s=--silent
	#s=--verbose
	#set -vx
	curl $s \
		http://$QBT_HOST/api/v2/$1/$2 \
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

# show all active torrents | get their peers | grep by ip
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
		jq -r '.[] | [ .hash, .category, .content_path, .progress*100 ] | @tsv' | \
		zstdmt --adapt | tee $tmp | zstdmt -d
	;;
tfiles)
	torrents files -G \
		--data "hash=$2" | \
		jq -r '.[] | [ .name, .progress*100, .size/1024/1024/1024 ] | @tsv'
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
		jq -r '.[] | [ .hash, .category, .content_path, .progress*100 ] | @tsv'
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
	[ -z "$2" ] && echo specify location as first arg && exit -1
	hashes=$(paste -sd\|)
	torrents setLocation -X POST --data "hashes=$hashes" --data "location=$2"
	;;
set_category)
	[ -z "$2" ] && echo specify catgory as first arg && exit -1
	hashes=$(paste -sd\|)
	torrents setCategory -X POST --data "hashes=$hashes" --data "category=$2"
	;;
qtop)
	hashes=$(paste -sd\|)
	torrents topPrio -X POST --data "hashes=$hashes"
	;;
qbottom)
	hashes=$(paste -sd\|)
	torrents bottomPrio -X POST --data "hashes=$hashes"
	;;

peerhashes)
	parallel peerhashes
	;;
connections)
	parallel 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | [ .ip, .country ] | @tsv"'
	;;
peerfiles)
	parallel --tag -k peerfiles
	;;

# "peers_country" by hashes
countries)
	#parallel -k 'sync torrentPeers -G --data "hash={}"'
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
		--data "filter=uploading" \
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
		--data "filter=downloading" \
		--data "filter=active" | \
		jq -r '.[] | [ .category, .name, .dlspeed/1024/1024, .progress*100 ] | @tsv' | \
		column --table -N category,name,dlspeed,completed -s$'\t'
	echo
	transfer info | \
		jq -r '[ .connection_status, .dht_nodes, .dl_info_speed/1024/1204, .up_info_speed/1024/1024, ( .dl_info_speed + .up_info_speed )/1024/1024, .dl_rate_limit/1024/1024, .up_rate_limit/1024/1024 ] | @tsv' | \
		column --table -N status,dhtnodes,dl,up,total,dl_rl,up_rl, -s$'\t'
	;;

togglespeed)
	# wtf: GET reqest returns 405
	transfer toggleSpeedLimitsMode -X POST
	;;

top)
	sort | uniq -c | sort -n # without -r it's actually a `bottom`
	;;
rawtop)
	qbtlib.sh top | sed 's/ *[0-9]* //'
	;;


# systemd-run --user -E PATH --on-calendar=minutely -- bash qbtlib.sh influx
influx)
	sdir=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
	read token <$sdir/.token.influx

	cat >/tmp/qbtlib.sh.influx.data << EOF
	active_torrents,host=$QBT_HOST value=$(qbtlib.sh active | wc -l) $(date +%s)
	connections,host=$QBT_HOST value=$(qbtlib.sh active | cut -f1 | qbtlib.sh connections | wc -l) $(date +%s)
	dl_speed,host=$QBT_HOST value=$(transfer info | jq -r .dl_info_speed) $(date +%s)
	up_speed,host=$QBT_HOST value=$(transfer info | jq -r .up_info_speed) $(date +%s)
EOF

	curl -S -s \
		'http://influx.lan/api/v2/write?org=h0me&bucket=qbt&precision=s' \
		--header "Authorization: Token $token" \
		--data-binary @/tmp/qbtlib.sh.influx.data

	;;


*)
	echo no such command
	exit -1
	;;

esac

set +vx
