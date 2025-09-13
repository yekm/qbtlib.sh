#!/bin/bash

#set -u

export PATH=$BASH_SOURCE:$PATH

export QBT_HOST=${QBT_HOST:-localhost:8283}
tmpfile=/tmp/qbtlib.sh.${QBT_HOST}
cachefile=$tmpfile.json.zst
shlog=/tmp/qbtlib_speedhistory.log

debuglog() {
	echo "$(date +%F_%R) $@" >/dev/stderr
}
export -f debuglog

die() {
	echo $@
	exit 1
}

helpall() {
	argn=$(grep -P '^[\w\.]+\)' ${BASH_SOURCE[0]} | wc -l)
	helpn=$(grep -w ' -n "$help" ] && die ' ${BASH_SOURCE[0]} | grep -v helpn | wc -l)
	[ $argn -ne $helpn ] && echo incomplete help $helpn of $argn args && exit -1

	# grep possible arguments from self
	cat ${BASH_SOURCE[0]} | grep -P '^[\w\.]+\)' | tr -d ')' |
		parallel --tag -k qbtlib.sh help | qbtlib.sh table
	cat << EOF

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
EOF
}

_apicall() {
	s=--silent
	#s=--verbose
	#s=--trace-ascii /tmp/curl.trace
	#set -vx
	[ "x$DEBUG" = "x1" ] && debuglog "curl http://$QBT_HOST/api/v2/$1/$2"
	[ "x$DEBUG" = "x2" ] && debuglog "curl http://$QBT_HOST/api/v2/$1/$2 ${@:3}"
	curl -S -f $s \
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
	cat ${1:-$cachefile} |
		zstdmt -d |
		jq -r '.[] | [ .hash, .category, .content_path, .progress*100 ] | @tsv'
	# todo: tmp cleanup
	;;
cache1)
	[ -n "$help" ] && die '... print only hashes from cached `qbtlib.sh last`'
	cf=$cachefile
	[ "$cf" -nt "$cf-1" ] && qbtlib.sh cache.js |
		jq -r '.[] | [ .hash ] | @tsv' >"$cf-1"
	cat "$cf-1"
	;;
cache.js)
	[ -n "$help" ] && die '... print cached `qbtlib.sh last` in json'
	cat ${1:-$cachefile} |
		zstdmt -d
	;;
cache.custom)
	[ -n "$help" ] && die '... print cached `qbtlib.sh last` with custom jq selector columns in arg1, like .hash, .category, .content_path, .progress*100'
	qbtlib.sh cache.js |
		jq -r ".[] | [ $@ ] | @tsv"
	;;
last)
	[ -n "$help" ] && die '... list torrents sotred by `added_on`'
	torrents info -G --data "sort=added_on" |
		zstdmt --adapt > $cachefile
	qbtlib.sh cache
	;;
last.r)
	[ -n "$help" ] && die '... list torrents sotred by `ratio`'
	torrents info -G --data "sort=ratio" |
		zstdmt --adapt | tee $cachefile | zstdmt -d |
		jq -r '.[] | [ .hash, .category, .content_path, .progress*100, .ratio ] | @tsv' |
		cut -f2-
	;;

active)
	[ -n "$help" ] && die '... list torrents sotred by `added_on` filtered by `active`'
	qbtlib.sh active.js |
		jq -r '.[] | [ .hash, .category, .content_path, .progress*100 ] | @tsv'
	;;
active1)
	[ -n "$help" ] && die '... list only hashes sotred by `added_on` filtered by `active`'
	qbtlib.sh active | cut -f1
	;;
active.js)
	[ -n "$help" ] && die '... list torrents sotred by `added_on` filtered by `active` in json'
	torrents info -G --data "sort=added_on" --data "filter=active" |
		jq
	;;

info.js)
	[ -n "$help" ] && die '... list torrents sotred by `added_on` filtered by `active` in json'
	torrents info -G $@ |
		jq
	;;

tinfo.js)
	[ -n "$help" ] && die 'h|p torrent info in json'
	hashes=$(paste -sd\|)
	torrents info -G --data "hashes=$hashes" |
		jq
	;;
tinfo)
	[ -n "$help" ] && die 'h|p torrent info'
	qbtlib.sh tinfo.js |
		jq -r '.[]' |
		qbtlib.sh js.table
	;;
tinfo.my)
	[ -n "$help" ] && die 'h|p torrent info in custom format'
	qbtlib.sh tinfo.js |
		jq -r '.[] | [ .content_path, .progress, .state, .comment, .total_size/1024/1024, .hash ] | @tsv' |
		qbtlib.sh table
	;;
texists)
	[ -n "$help" ] && die '... <arg1> check if torrent with hash arg1 exists'
	# TODO: use recent cache
	[ -z "$1" ] && exit -1
	qbtlib.sh cache1 | grep -qwi $1 && exit 0
	echo $1 | qbtlib.sh tinfo | grep -qwi $1 || exit -1
	;;

resume)
	[ -n "$help" ] && die 'h|p resume torrents'
	hashes=$(paste -sd\|)
	torrents start -X POST --data "hashes=$hashes"
	;;
startnow)
	[ -n "$help" ] && die 'h|p resume and queue top torrents'
	hashes=$(paste -sd\|)
	torrents start -X POST --data "hashes=$hashes"
	torrents topPrio -X POST --data "hashes=$hashes"
	;;
stop)
	[ -n "$help" ] && die 'h|p stop torrents'
	hashes=$(paste -sd\|)
	torrents stop -X POST --data "hashes=$hashes"
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

add)
	[ -n "$help" ] && die "... <filename> [args] add torrent. optional args -F savepath= -F category= -F tags= -F paused=true"
	[ -s "$1" ] || die 'specify torrent filename'
	t=$(mktemp --suffix=qbtlib)
	cp "$1" $t
	torrents add -F "torrents=@$t;type=application/x-bittorrent" \
		${@:2}
	rm $t
	echo
	# -F savepath= -F category= -F tags= -F paused=true
	;;
delete)
	[ -n "$help" ] && die 'h|p [`arg1`] delete torrents, arg1 can be "deletefilestoo"'
	opt="--data deleteFiles=false"
	[ "$1" = "deletefilestoo" ] && opt="--data deleteFiles=true"
	hashes=$(paste -sd\|)
	torrents delete -X POST $opt --data "hashes=$hashes"
	;;


############# Files ############################################################

tfiles)
	[ -n "$help" ] && die '... <hash> list files by one `hash` (name, priority, progress, size in GiB, name)'
	[ -z "$1" ] && die 'specify hash as first argument'

	torrents files -G --data "hash=$1" |
		jq -r '.[] | [ .index, .priority, .progress*100, .size/1024/1024/1024, .name ] | @tsv' |
		sort -k2
	;;
tfiles.js)
	[ -n "$help" ] && die '... <hash> list files by one `hash` in json'
	[ -z "$1" ] && die 'specify hash as first argument'
	torrents files -G --data "hash=$1" | jq
	;;

setfpriority)
	[ -n "$help" ] && die 'id|p <arg1> <arg2> set pieces priority to `arg2` (0,1,6,7) for torrent with hash `arg1`'
	[ -z "$1" ] && die specify torrent hash
	[ -z "$2" ] && die specity pieces priority
	ids=$(paste -sd\|)
	torrents filePrio -X POST --data "hash=$1" --data "priority=$2" --data "id=$ids"
	;;

pieces)
	[ -n "$help" ] && die '... <hash> show torrent pieces'
	torrents pieceStates -G --data "hash=$1" | tr -d ',[]' | tr 012 .v*
	echo
	;;

cpath)
	[ -n "$help" ] && die 'h|p list content path by hashes'
	hashes=$(paste -sd\|)
	torrents info -G --data "hashes=$hashes" |
		jq -r '.[] | [ .category, .content_path ] | @tsv' |
		sort |
		qbtlib.sh table
	;;

get_location)
    [ -n "$help" ] && die 'h|p get torrent locations'
    qbtlib.sh tinfo.js | jq -r '.[] | [ .hash, .content_path] | @tsv'
    ;;
set_location)
	[ -n "$help" ] && die 'h|p <arg1> moves torrents to a new location `arg1`'
	[ -z "$1" ] && die specify location as first arg
	hashes=$(paste -sd\|)
	torrents setLocation -X POST --data "hashes=$hashes" --data "location=$1"
	;;
sed_location)
    #die 'fix escaping issues first'
    [ -n "$help" ] && die 'h|p <arg1> moves torrents to a new location `echo old_location | sed arg1`'
    [ -z "$1" ] && die specify sed expression
	qbtlib.sh get_location | sed $1 | parallel --colsep=$'\t' torrents setLocation -X POST --data "hashes={1}" --data 'location={=2 $_=Q($arg[2]) =}'
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

tracker1)
	[ -n "$help" ] && die 'h|. list trackers'
	torrents trackers --data "hash=$1" |
		jq -r '.[] | [ .tier, .url, .status, .num_peers, .num_seeds, .num_downloaded, .msg ] | @tsv '
	;;

trackers)
	[ -n "$help" ] && die 'h|. list trackers'
	parallel --tag qbtlib.sh tracker1
	;;

tracker_add)
	[ -n "$help" ] && die 'h|. <tracker_url> add tracker url to torrents'
	parallel torrents addTrackers -X POST --data "hash={}" --data "urls=$1"
	;;


############# Peers ############################################################

peers)
	[ -n "$help" ] && die 'h|. list peers on a hash sorted by country, like in webui'
	parallel --tag 'sync torrentPeers -G --data "hash={}" | \
			jq -r ".peers | to_entries | .[].value | [ .country_code, .ip, .port, .connection, .flags, .client, .progress, .dl_speed, .downloada, .up_speed, .uploaded, .relevance, .files ] | @tsv"'
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
	parallel --tag 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .ip"' |
		sort
	;;
connections2)
	[ -n "$help" ] && die 'h|. list peers on a hash sorted by country'
	parallel 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | [ .country, .ip, .flags ] | @tsv"' |
		sort
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
	qbtlib.sh active1 |
		qbtlib.sh icountries |
		grep -i "$1" |
		rev | uniq -f1 | rev
	;;

# jq's floor should be embedded in an arrray.
# echo '{"mass": 188.72, "shit": 100}' | jq ' [ [.mass|floor] , .shit ] | flatten'
# looks ugly
monitor)
	[ -n "$help" ] && die '... list uploading torrent to sorted by `upspeed`'
	cc=$(( $(tput cols) - 32 ))
	torrents info -G \
			--data "sort=upspeed" \
			--data "filter=uploading" \
			--data "filter=active" |
		jq -r '.[] | [ .category, .name, .upspeed/1024/1024, .progress*100 ] | @tsv' |
		awk 'BEGIN { FS=OFS="\t" } {
			$1 = substr($1,0,18);
			$2 = substr($2,0,'$cc');
			$3 = substr($3,0,5);
			$4 = substr($4,0,4);
			print $1"\t"$2"\t"$3"\t"$4; }' |
		qbtlib.sh table -o' ' -N cat,name,up,done -R 3,4
	echo
	transfer info |
		jq -r '[ .connection_status, .dht_nodes, .dl_info_speed/1024/1204, .up_info_speed/1024/1024, ( .dl_info_speed + .up_info_speed )/1024/1024 ] | @tsv' |
		qbtlib.sh table -N status,dhtnodes,dl,up,total
	;;
monitor_dl)
	[ -n "$help" ] && die '... list downloading torrent to sorted by `dlspeed`'
	cc=$(( $(tput cols) - 32 ))
	torrents info -G \
			--data "sort=dlspeed" \
			--data "filter=downloading" \
			--data "filter=active" |
		jq -r '.[] | [ .category, .name, .dlspeed/1024/1024, .progress*100 ] | @tsv' |
		awk 'BEGIN { FS=OFS="\t" } {
			$1 = substr($1,0,18);
			$2 = substr($2,0,'$cc');
			$3 = substr($3,0,5);
			$4 = substr($4,0,4);
			print $1"\t"$2"\t"$3"\t"$4; }' |
		qbtlib.sh table -o' ' -N cat,name,MiB/s,done -R 3,4
	echo
	transfer info |
		jq -r '[ .connection_status, .dht_nodes, .dl_info_speed/1024/1204, .up_info_speed/1024/1024, ( .dl_info_speed + .up_info_speed )/1024/1024, .dl_rate_limit/1024/1024, .up_rate_limit/1024/1024 ] | @tsv' |
		qbtlib.sh table -N status,dhtnodes,dl,up,total,dl_rl,up_rl
	;;

kick_stalled_dl)
	[ -n "$help" ] && die '... [delay] deprioritise incomplete stalled downloading torrents'

	while true; do
		qbtlib.sh info.js --data "filter=stalled_downloading" |
			jq -r '.[] | select(.progress < 0.5) | [ .hash, .name, .progress*100, .dlspeed ] | @tsv' |
			tee -a /dev/tty |
			cut -f1 |
			qbtlib.sh qbottom
		[ -z "$1" ] && exit
		date
		sleep $1
	done
;;

############# Preferences ######################################################

togglespeed)
	[ -n "$help" ] && die '... toggle alternative speed limits'
	# wtf: GET reqest returns 405
	transfer toggleSpeedLimitsMode -X POST
	;;

gspeed)
	[ -n "$help" ] && die '... [ul] [dl] get/set global up/dl limits in MiB/s'
	[ $# -ne 0 ] && echo "down limit $(transfer downloadLimit), up limit $(transfer uploadLimit) before"
	[ -n "$1" ] && transfer setUploadLimit --data limit=$(( $1 * 1024 * 1024 ))
	[ -n "$2" ] && transfer setDownloadLimit --data limit=$(( $2 * 1024 * 1024 ))
	echo "down limit $(transfer downloadLimit) up limit $(transfer uploadLimit)"
	;;

speednow)
	[ -n "$help" ] && die "... current speed ul dl"
	transfer info |
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
	[ -s "$1" ] && app setPreferences --data-urlencode json@$1 && exit 0
	app preferences | tee -a $t | jq
	;;

pref_sed)
	[ -n "$help" ] && die '... <arg1> set new preferences filtered by sed arg1'
	set -e
	qbtlib.sh pref.js | sed "$1" >/tmp/qbtlib_pref.sed.tmp
	qbtlib.sh pref.js /tmp/qbtlib_pref.sed.tmp
	#app preferences | tee -a $t | jq
	;;

pref)
	[ -n "$help" ] && die "... app preferences"
	app preferences |
		jq -r 'to_entries | map(select(.key != "scan_dirs"))[] | [ .key, .value ] | @tsv' |
		qbtlib.sh table |
		less
	;;

pref_set)
	[ -n "$help" ] && die '... <arg1> <arg2> set option arg1 to arg2'
	[ -z "$1" ] && die 'specify an option name'

	qbtlib.sh pref.js | grep -w "$1" || die no such pref option

	[ -z "$2" ] && die specify value
	
	qbtlib.sh pref_sed 's/"'$1'": .*/"'$1'": '$2',/'
	qbtlib.sh pref.js | grep -w "$1"
	;;

stat.countries)
	[ -n "$help" ] && die "... top countries of all active torrents"
	qbtlib.sh active1 |
		qbtlib.sh peers |
		cut -f2 |
		qbtlib.sh top
	;;
	
stat.clients)
	[ -n "$help" ] && die "... top client's software of all active torrents"
	qbtlib.sh active1 |
		qbtlib.sh peers |
		cut -f7 | cut -f1 -d' ' | cut -f1 -d/ | tr 'A-Z' 'a-z' |
		sed 's/^$/empty/' |
		qbtlib.sh top
	;;

stat)
	[ -n "$help" ] && die "... display overall statistics"
	transfer info |
		jq -r '[ .connection_status, .dht_nodes, .dl_info_speed/1024/1204, .up_info_speed/1024/1024, ( .dl_info_speed + .up_info_speed )/1024/1024, .dl_rate_limit/1024/1024, .up_rate_limit/1024/1024 ] | @tsv' |
		qbtlib.sh table -N "status,dhtnodes,dl MiB/s,up MiB/s,total MiB/s,ratelimit dl MiB/s,ratelimit up MiB/s"

	qbtlib.sh stat.countries
	qbtlib.sh stat.clients

	qbtlib.sh cache.custom '.state' | qbtlib.sh top
	qbtlib.sh cache.custom '.category' | qbtlib.sh top

	qbtlib.sh cache.custom '.category' | qbtlib.sh rawtop |
		parallel -j50% --tag 'qbtlib.sh cache.custom ".size, .category" | grep -w "{= uq =}" | cut -f1 | qbtlib.sh bsum' |
		sort -k2 -n |
		qbtlib.sh table
	;;
stat.png)
	[ -n "$help" ] && die "... generate ratio-size scatter plot"
	png=/tmp/qbtlib-stat-ratio-size-$(date +%F_%R).png
	qbtlib.sh cache.js | jq -r '.[] | [ .ratio, .size ] | @tsv' |
		gnuplot -p -e "\
			set terminal pngcairo size 1920,1080; \
			set style fill transparent solid 0.02 noborder; \
			set style circle radius 4; \
			set logscale y; \
			set logscale x; \
			plot '-' u 1:2 with circles lc rgb 'red'\
			" \
		>$png
		ls -lah $png
	exit
	# todo:
	qbtlib.sh cache.js | jq -r '.[] | .ratio' |
		sort |
		gnuplot -p -e \
			"set terminal dumb size 120, 30; \
			binwidth=10; \
			set boxwidth binwidth; \
			bin(x,width)=width*floor(x/width); \
			set logscale y; \
			plot '-' using (bin(\$1,binwidth)):(1.0) smooth freq with boxes"
	qbtlib.sh cache.js | jq -r '.[] | .size' |
		sort |
		gnuplot -p -e \
			"set terminal dumb size 120, 30; \
			binwidth=1000000; \
			set boxwidth binwidth; \
			bin(x,width)=width*floor(x/width); \
			set logscale y; \
			plot '-' using (bin(\$1,binwidth)):(1.0) smooth freq with boxes"
	;;

log)
	[ -n "$help" ] && die "... display log"
	_apicall log main |
		jq -r '.[] | [.id, .type, .timestamp, .message] | @tsv' |
		qbtlib.sh table
	;;


############# related stuff ####################################################
# parallel "systemd-run --user -E PATH -E QBT_HOST=localhost:{} --on-calendar='*:00/10:00 -- bash qbtlib.sh influx" ::: 8283 8284 8285
influx)
	[ -n "$help" ] && die "... store number of active torrents and connections, and ul dl speed in influxdb"
	sdir=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
	read token <$sdir/.token.influx

	# all sorts of weird stuff in grafana without aligned time in data points
	d=$(date +%s)

	state=$(torrents info -G | jq -r '.[] | .state' | qbtlib.sh top | awk '{print "echo "$2",stat=state,host=$QBT_HOST value="$1" $d"}')
	clients=$(qbtlib.sh stat.clients | awk '{print "echo "$2",stat=clients,host=$QBT_HOST value="$1" $d"}')
	countries=$(qbtlib.sh stat.countries | awk '{print "echo "$2",stat=countries,host=$QBT_HOST value="$1" $d"}')

	idata=$tmpfile.influx.data
	cat >$idata << EOF
	active_torrents,host=$QBT_HOST value=$(qbtlib.sh active | wc -l) $d
	connections,host=$QBT_HOST value=$(qbtlib.sh active1 | qbtlib.sh connections | wc -l) $d
	dl_speed,stat=speed,host=$QBT_HOST value=$(transfer info | jq -r .dl_info_speed) $d
	up_speed,stat=speed,host=$QBT_HOST value=$(transfer info | jq -r .up_info_speed) $d
	max_connec,host=$QBT_HOST value=$(qbtlib.sh pref.js | jq -r .max_connec) $d
	$(eval "$state")
	$(eval "$clients")
	$(eval "$countries")
EOF

	[ -n "$DEBUG" ] && cat $idata && exit

	curl -S -s \
		'http://influx.lan/api/v2/write?org=h0me&bucket=qbt&precision=s' \
		--header "Authorization: Token $token" \
		--data-binary @$idata

	;;


# systemd-run --user -E PATH --on-calendar=minutely -- bash qbtlib.sh appendspeedhistory
appendspeedhistory)
	[ -n "$help" ] && die "... apeend writes current date and speed in $shlog"
	printf "%s\t%s\t%s\t%s\n" $QBT_HOST $(date +%s) $(qbtlib.sh speednow) |
		sem --id shlog tee -a $shlog
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

############# utilities ########################################################

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
	jq -r 'to_entries | map(select(.key != "null"))[] | [ .key, .value ] | @tsv' |
		qbtlib.sh table "$@" |
		less
	;;

_sum)
	[ -n "$help" ] && die ".|. add up all numbers"
	paste -sd+ |
		parallel 'python -c "print({})"'
	# or with bc, which cant into scientific notation:
	# grep -v e | paste -sd+ | bc -l
	;;
sum)
	[ -n "$help" ] && die ".|. add up a lot of numbers"
	parallel --pipe -n4096 qbtlib.sh _sum |
		qbtlib.sh _sum
	;;

bytes)
	[ -n "$help" ] && die ".|. pretty print amount of bytes"
	set -e
	which qalc >/dev/null
	sed "s/$/ bytes/" |
		qalc --set "color 0" |
		grep B$
	;;

bsum)
	[ -n "$help" ] && die ".|. add up a lot of numbers, pretty print as bytes"
	qbtlib.sh sum | qbtlib.sh bytes
	;;

*)
	die no such command
	;;

esac

set +vx
