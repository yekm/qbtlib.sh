#!/bin/bash

#set -u

export PATH=$BASH_SOURCE:$PATH

tmp=/tmp/qbtlib.sh.cache_$(date +%F_%R).zst
shlog=/tmp/qbtlib_speedhistory.log

export QBT_HOST=${QBT_HOST:-localhost:8283}

_apicall() {
	s=--silent
	#s=--verbose
	#set -vx
	curl -S $s \
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


cmd=$1
shift
case $cmd in
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
		--data "hash=$1" | \
		jq -r '.[] | [ .name, .progress*100, .size/1024/1024/1024 ] | @tsv'
	;;
cpath)
	torrents info -G \
		--data "hashes=$1" | \
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
	[ -z "$1" ] && echo specify location as first arg && exit -1
	hashes=$(paste -sd\|)
	torrents setLocation -X POST --data "hashes=$hashes" --data "location=$1"
	;;
set_category)
	[ -z "$1" ] && echo specify catgory as first arg && exit -1
	hashes=$(paste -sd\|)
	torrents setCategory -X POST --data "hashes=$hashes" --data "category=$1"
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
connections2)
	parallel 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | [ .country, .ip, .flags ] | @tsv"'
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
	qbtlib.sh active | cut -f1 | qbtlib.sh icountries | grep "$1" | rev | uniq -f1 | rev
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

gspeed)
	[ $# -eq 0 ] && echo "up limit $(transfer downloadLimit) down limit $(transfer uploadLimit)"
	# global speed limits in MiB
	[ -n "$1" ] && transfer setUploadLimit --data limit=$(( $1 * 1024 * 1024 ))
	[ -n "$2" ] && transfer setDownloadLimit --data limit=$(( $2 * 1024 * 1024 ))
	;;

speednow)
	transfer info | \
		jq -r '[ .up_info_speed/1024/1024, .dl_info_speed/1024/1204 ] | @tsv'
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

	# all sorts of weird stuff in grafana without aligned time in data points
	d=$(date +%s)

	cat >/tmp/qbtlib.sh.influx.data << EOF
	active_torrents,host=$QBT_HOST value=$(qbtlib.sh active | wc -l) $d
	connections,host=$QBT_HOST value=$(qbtlib.sh active | cut -f1 | qbtlib.sh connections | wc -l) $d
	dl_speed,host=$QBT_HOST value=$(transfer info | jq -r .dl_info_speed) $d
	up_speed,host=$QBT_HOST value=$(transfer info | jq -r .up_info_speed) $d
EOF

	curl -S -s \
		'http://influx.lan/api/v2/write?org=h0me&bucket=qbt&precision=s' \
		--header "Authorization: Token $token" \
		--data-binary @/tmp/qbtlib.sh.influx.data

	;;


# systemd-run --user -E PATH --on-calendar=minutely -- bash qbtlib.sh speedhistory ishotthesherrifff
speedhistory)
	# nb: infinitie memory fill
	if [ "$1" = "ishotthesherrifff" ] ; then
		printf "%s\t%s\t%s\t%s\n" $QBT_HOST $(date +%s) $(qbtlib.sh speednow) | tee -a $shlog
		exit
	fi

	cat $shlog | grep $QBT_HOST | cut -f 2-4 | \
		gnuplot -p -e "set timefmt '%s'; set xdata time; plot '-' using 1:2 with lines"
;;

ss)
	cat $shlog | grep $QBT_HOST
;;

# https://github.com/holman/spark
sparkhistory)
	cc=$(( $(tput cols) - 32 ))
	max_ul=$(cat $shlog | cut -f 3 | grep -v ^$ | sort | tail -n1)
	min_ul=$(cat $shlog | cut -f 3 | grep -v ^$ | sort | head -n1)
	max_dl=$(cat $shlog | cut -f 4 | grep -v ^$ | sort | tail -n1)
	min_dl=$(cat $shlog | cut -f 4 | grep -v ^$ | sort | head -n1)
	now=$(date +%R -d @$(tail -n1 $shlog | cut -f 2))
	then=$(date +%R -d @$(head -n1 $shlog | cut -f 2))
	printf "$cc max    / min %8s %${cc}s\n" "$now" "$then"
	then=$(date +%R -d @$(tail -n$cc $shlog | head -n1 | cut -f 2))
	printf "ul %7.3f/%7.3f %s %s %s\n" $max_ul $min_ul "$(tail -n $cc $shlog | cut -f 3 | tac | spark)" "$then"
	printf "dl %7.3f/%7.3f %s %s %s\n" $max_dl $min_dl "$(tail -n $cc $shlog | cut -f 4 | tac | spark)" "$then"
;;

*)
	echo no such command
	exit -1
	;;

esac

set +vx
