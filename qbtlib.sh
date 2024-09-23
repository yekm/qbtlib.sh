#!/bin/bash

#set -u

export PATH=$BASH_SOURCE:$PATH

tmp=/tmp/qbtlib.sh.cache_$(date +%F_%R).zst
shlog=/tmp/qbtlib_speedhistory.log

export QBT_HOST=${QBT_HOST:-localhost:8283}

die() {
	echo $@
	exit 1
}

helpall() {
	argn=$(grep -P '^[\w\.]+\)' ${BASH_SOURCE[0]} | wc -l)
	helpn=$(grep -w ' -n "$help" ] && die ' ${BASH_SOURCE[0]} | grep -v helpn | wc -l)
	[ $argn -ne $helpn ] && echo incomplete help $helpn of $argn args && exit -1

	# grep possible arguments from self
	cat ${BASH_SOURCE[0]} | grep -P '^[\w\.]+\)' | tr -d ')' | \
		parallel --tag -k qbtlib.sh help | qbtlib.sh table
	cat << EOF

examples:
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
EOF
}

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

app() {
	_apicall app $@
}

# show all active torrents | get their peers | grep by ip
peerhashes() {
	qbtlib.sh active1 | qbtlib.sh connections | grep -F -w "$1"
}
peerpaths() {
	peerhashes $1 | cut -f1 | qbtlib.sh cpath
}

tstate() {
	echo $1 | qbtlib.sh tinfo | jq -r ".[] | .state"
}

# error missingFiles uploading pausedUP queuedUP stalledUP checkingUP forcedUP allocating downloading metaDL pausedDL queuedDL stalledDL checkingDL forcedDL checkingResumeData moving unknown 

recheckwait() {
	tstate $1 | grep \
		-e checkingUP \
		-e checkingDL \
		-e allocating \
		-e downloading \
		-e metaDL \
		-e pausedDL \
		-e queuedDL \
		-e stalledDL \
		-e checkingResumeData \
		-e moving \
		-e unknown \
	&& exit

	echo $1 | qbtlib.sh recheck

	# waiting for qbt to start checking
	i=0
	while [ $(tstate $1) != "checkingUP" ]; do
		(( i++ ))
		if [ $i -gt 16 ]; then
			echo -n TIMEOUT in $i seconds:\ 
			echo $1 | qbtlib.sh tinfo | jq -r ".[] | [.state, .name] | @tsv"
			exit
		fi
		sleep 1
	done

	# waiting for qbt to end checking
	while [ $(tstate $1) == "checkingUP" ]; do
		sleep 2
	done
	echo -n recheck done:\ 
	echo $1 | qbtlib.sh tinfo | jq -r ".[] | [.state, .name] | @tsv"
}

export -f _apicall torrents sync peerhashes peerpaths recheckwait tstate


cmd=$1
shift
if [ "$cmd" = "help" ]; then
	help=1
	cmd=$1
	shift
fi

[ -z "$cmd" ] && helpall && die

case $cmd in
cache)
	[ -n "$help" ] && die '... print cached `qbtlib.sh last`'
	cat $(ls -1t /tmp/qbtlib.sh.cache_* | head -n1) \
		| zstdmt -d \
		| jq -r '.[] | [ .hash, .category, .content_path, .progress*100 ] | @tsv'
	# todo: tmp cleanup
	;;
cache1)
	[ -n "$help" ] && die '... print only hashes from cached `qbtlib.sh last`'
	qbtlib.sh cache | cut -f1
	;;
cache.js)
	[ -n "$help" ] && die '... print cached `qbtlib.sh last` in json'
	cat $(ls -1t /tmp/qbtlib.sh.cache_* | head -n1) \
		| zstdmt -d
	;;
last)
	[ -n "$help" ] && die '... list torrents sotred by `added_on`'
	torrents info -G --data "sort=added_on" | \
		zstdmt --adapt | tee $tmp | zstdmt -d | \
		jq -r '.[] | [ .hash, .category, .content_path, .progress*100 ] | @tsv'
	;;
active)
	[ -n "$help" ] && die '... list torrents sotred by `added_on` filtered by `active`'
	torrents info -G \
		--data "sort=added_on" \
		--data "filter=active" | \
		jq -r '.[] | [ .hash, .category, .content_path, .progress*100 ] | @tsv'
	;;
active1)
	[ -n "$help" ] && die '... list only hashes sotred by `added_on` filtered by `active`'
	qbtlib.sh active | cut -f1
	;;
active.js)
	[ -n "$help" ] && die '... list torrents sotred by `added_on` filtered by `active` in json'
	torrents info -G \
		--data "sort=added_on" \
		--data "filter=active" | \
		jq
	;;
tinfo.js)
	[ -n "$help" ] && die 'h|p torrent info in json'
	hashes=$(paste -sd\|)
	torrents info -G \
		--data "hashes=$hashes" | jq
	;;
tinfo)
	[ -n "$help" ] && die 'h|p torrent info'
	qbtlib.sh tinfo.js | jq -r '.[]' | qbtlib.sh js.table
	;;
resume)
	[ -n "$help" ] && die 'h|p resume torrents'
	hashes=$(paste -sd\|)
	torrents resume -X POST --data "hashes=$hashes"
	;;
pause)
	[ -n "$help" ] && die 'h|p pause torrents'
	hashes=$(paste -sd\|)
	torrents pause -X POST --data "hashes=$hashes"
	;;
recheck)
	[ -n "$help" ] && die 'h|p recheck torrents'
	hashes=$(paste -sd\|)
	torrents recheck -X POST --data "hashes=$hashes"
	;;
slowcheck)
	[ -n "$help" ] && die 'h|. [arg1=2] recheck torrents `arg1` at a time, default 2'
	j=${1:-2}
	parallel -j$j --joblog slowcheck.joblog --halt soon,fail=1 --resume --eta --lb --tag recheckwait
	;;

tfiles)
	[ -n "$help" ] && die '... <hash> list files by one `hash` (index, name, priority, progress, size in GiB)'
	torrents files -G --data "hash=$1" | \
		jq -r '.[] | [ .index, .name, .priority, .progress*100, .size/1024/1024/1024 ] | @tsv'
	;;
tfiles.js)
	[ -n "$help" ] && die '... <hash> list files by one `hash` in json'
	torrents files -G --data "hash=$1" | jq
	;;

pieces)
	[ -n "$help" ] && die '... <hash> show torrent pieces'
	torrents pieceStates -G --data "hash=$1" | tr -d ',[]' | tr 012 .v*
	echo
	;;
setfpriority)
	[ -n "$help" ] && die 'id|p <arg1> <arg2> set pieces priority to `arg2` (0,1,6,7) for torrent with hash `arg1`'
	[ -z "$1" ] && die specify torrent hash
	[ -z "$2" ] && die specity pieces priority
	ids=$(paste -sd\|)
	torrents filePrio -X POST --data "hash=$1" --data "priority=$2" --data "id=$ids"
	;;

cpath)
	[ -n "$help" ] && die 'h|p list content path by hashes'
	hashes=$(paste -sd\|)
	torrents info -G \
		--data "hashes=$hashes" | \
		jq -r '.[] | [ .category, .content_path ] | @tsv' | sort | qbtlib.sh table
	;;

set_location)
	[ -n "$help" ] && die 'h|p <arg1> moves torrents to a new location `arg1`'
	[ -z "$1" ] && die specify location as first arg
	hashes=$(paste -sd\|)
	torrents setLocation -X POST --data "hashes=$hashes" --data "location=$1"
	;;
set_category)
	[ -n "$help" ] && die 'h|p <arg1> set cetegory to `<arg1>` on torrents'
	[ -z "$1" ] && die specify catgory as first arg
	hashes=$(paste -sd\|)
	torrents setCategory -X POST --data "hashes=$hashes" --data "category=$1"
	;;

qtop)
	[ -n "$help" ] && die 'h|p move torrents on top of the queue'
	hashes=$(paste -sd\|)
	torrents topPrio -X POST --data "hashes=$hashes"
	;;
qbottom)
	[ -n "$help" ] && die 'h|p move torrents on bottom of the queue'
	hashes=$(paste -sd\|)
	torrents bottomPrio -X POST --data "hashes=$hashes"
	;;


peerhashes)
	[ -n "$help" ] && die 'ip| list hashes on a peer'
	parallel --tag -k peerhashes
	;;
peerpaths)
	[ -n "$help" ] && die 'ip| list content paths by peer'
	parallel --tag -k peerpaths
	;;
connections)
	[ -n "$help" ] && die 'h|. list peers on a hash'
	parallel --tag 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .ip"' | \
	sort
	;;
connections2)
	[ -n "$help" ] && die 'h|. list peers on a hash sorted by country'
	parallel 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | [ .country, .ip, .flags ] | @tsv"' \
		| sort
	;;

countries)
	[ -n "$help" ] && die 'h|. list peer countries by hash'
	parallel -k 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .country"'
	;;

icountries)
	[ -n "$help" ] && die 'h|. list peer countries by hash with --tag'
	parallel -k --tag 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .country"'
	;;

# "hash" by coutry
tcountries)
	[ -n "$help" ] && die '... <country> hashes by `country`. (active list icountries hashes grepped by `country`'
	qbtlib.sh active1 \
		| qbtlib.sh icountries \
		| grep -i "$1" \
		| rev | uniq -f1 | rev
	;;

# jq's floor should be embedded in an arrray.
# echo '{"mass": 188.72, "shit": 100}' | jq ' [ [.mass|floor] , .shit ] | flatten'
# looks ugly
monitor)
	[ -n "$help" ] && die '... list uploading torrent to sorted by `upspeed`'
	torrents info -G \
		--data "sort=upspeed" \
		--data "filter=uploading" \
		--data "filter=active" | \
		jq -r '.[] | [ .category, .name, .upspeed/1024/1024, .progress*100 ] | @tsv' | \
		qbtlib.sh table -o' ' -C name=category,width=1,strictwidth,trunc -C name=name,width=10,strictwidth -C name=up,width=1,strictwidth -C name=compl,width=1,strictwidth,trunc -T 0 -R 3,4 -m
	echo
	transfer info | \
		jq -r '[ .connection_status, .dht_nodes, .dl_info_speed/1024/1204, .up_info_speed/1024/1024, ( .dl_info_speed + .up_info_speed )/1024/1024 ] | @tsv' | \
		qbtlib.sh table -N status,dhtnodes,dl,up,total
	;;
monitor_dl)
	[ -n "$help" ] && die '... list downloading torrent to sorted by `dlspeed`'
	torrents info -G \
		--data "sort=dlspeed" \
		--data "filter=downloading" \
		--data "filter=active" | \
		jq -r '.[] | [ .category, .name, .dlspeed/1024/1024, .progress*100 ] | @tsv' | \
		qbtlib.sh table -N category,name,dlspeed,completed
	echo
	transfer info | \
		jq -r '[ .connection_status, .dht_nodes, .dl_info_speed/1024/1204, .up_info_speed/1024/1024, ( .dl_info_speed + .up_info_speed )/1024/1024, .dl_rate_limit/1024/1024, .up_rate_limit/1024/1024 ] | @tsv' | \
		qbtlib.sh table -N status,dhtnodes,dl,up,total,dl_rl,up_rl
	;;

togglespeed)
	[ -n "$help" ] && die '... toggle alternative speed limits'
	# wtf: GET reqest returns 405
	transfer toggleSpeedLimitsMode -X POST
	;;

gspeed)
	[ -n "$help" ] && die '... [ul] [dl] get/set global up/dl limits in MiB'
	[ $# -ne 0 ] && echo "up limit before $(transfer downloadLimit) down limit $(transfer uploadLimit)"
	[ -n "$1" ] && transfer setUploadLimit --data limit=$(( $1 * 1024 * 1024 ))
	[ -n "$2" ] && transfer setDownloadLimit --data limit=$(( $2 * 1024 * 1024 ))
	echo "up limit now $(transfer downloadLimit) down limit $(transfer uploadLimit)"
	;;

speednow)
	[ -n "$help" ] && die "... current speed ul dl"
	transfer info | \
		jq -r '[ .up_info_speed/1024/1024, .dl_info_speed/1024/1204 ] | @tsv'
	;;

sl)
	[ -n "$help" ] && die "... speed limits mode"
	echo -n "alternative speed limits "
	[ $(transfer speedLimitsMode) -eq 1 ] && echo enabled || echo disabled
	echo -n "scheduler "
	[ $(app preferences | jq -r .scheduler_enabled) = "true" ] && echo enabled || echo disabled
	;;

pref.js)
	[ -n "$help" ] && die '... [arg1] set new preferences from file `arg1` if exists. display preferences in json.'
	[ -s "$1" ] && app setPreferences --data-urlencode json@$1
	app preferences | tee -a $t | jq
	;;

pref)
	[ -n "$help" ] && die "... app preferences"
	app preferences \
		| jq -r 'to_entries | map(select(.key != "scan_dirs"))[] | [ .key, .value ] | @tsv' \
		| qbtlib.sh table \
		| less
	;;

top)
	[ -n "$help" ] && die ".|. actually bottom"
	sort | uniq -c "$@" | sort -n # without -r it's actually a `bottom`
	;;
rawtop)
	[ -n "$help" ] && die ".|. same as bove but without first column of numbers"
	qbtlib.sh top "$@" | sed 's/^ *[0-9]* //'
	;;

table)
	[ -n "$help" ] && die ".|. [] format tsv as table"
	column -t -s$'\t' "$@"
	;;
js.table)
	[ -n "$help" ] && die ".|. [] format json object key-values as table"
	jq -r 'to_entries | map(select(.key != "null"))[] | [ .key, .value ] | @tsv' \
		| qbtlib.sh table "$@" \
		| less
	;;

# systemd-run --user -E PATH --on-calendar=minutely -- bash qbtlib.sh influx
influx)
	[ -n "$help" ] && die "... store number of active torrents and connections, and ul dl speed in influxdb"
	sdir=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
	read token <$sdir/.token.influx

	# all sorts of weird stuff in grafana without aligned time in data points
	d=$(date +%s)

	cat >/tmp/qbtlib.sh.influx.data << EOF
	active_torrents,host=$QBT_HOST value=$(qbtlib.sh active | wc -l) $d
	connections,host=$QBT_HOST value=$(qbtlib.sh active1 | qbtlib.sh connections | wc -l) $d
	dl_speed,host=$QBT_HOST value=$(transfer info | jq -r .dl_info_speed) $d
	up_speed,host=$QBT_HOST value=$(transfer info | jq -r .up_info_speed) $d
EOF

	curl -S -s \
		'http://influx.lan/api/v2/write?org=h0me&bucket=qbt&precision=s' \
		--header "Authorization: Token $token" \
		--data-binary @/tmp/qbtlib.sh.influx.data

	;;


# systemd-run --user -E PATH --on-calendar=minutely -- bash qbtlib.sh appendspeedhistory
appendspeedhistory)
	[ -n "$help" ] && die "... apeend writes current date and speed in $shlog"
	printf "%s\t%s\t%s\t%s\n" $QBT_HOST $(date +%s) $(qbtlib.sh speednow) | tee -a $shlog
	;;

plotspeed)
	[ -n "$help" ] && die "... plot saved speed history with gnuplot"

	set -e
	which gnuplot >/dev/null
	[ -s $shlog ] || die 'no speed history file'

	t=$(mktemp)
	cat $shlog | grep $QBT_HOST | cut -f 2-4 >$t
	echo gnuplot quirks: hit enter to exit
	cat | gnuplot -p << EOF
	set timefmt '%s'
	set xdata time
	plot '$t' using 1:2 with lines lc "red" title "up", \
	     '$t' using 1:3 with lines lc "green" title "down"
EOF
	rm $t
;;

ss)
	[ -n "$help" ] && die "... cat $shlog"
	cat $shlog | grep $QBT_HOST
;;

# https://github.com/holman/spark
sparkhistory)
	[ -n "$help" ] && die "... ▇▅▃█▆"
	set -e
	which spark >/dev/null
	[ -s $shlog ] || die 'no speed history file'

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
	die no such command
	;;

esac

set +vx
