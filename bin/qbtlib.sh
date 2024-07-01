# usage:
# bash qbtlib.sh last | grep Отечественная | cut -f1 | bash qbtlib.sh resume
# bash qbtlib.sh active | cut -f1 | bash qbtlib.sh countries | sort | uniq -c | sort -n
# watch 'bash qbtlib.sh monitor | tail -n50'

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

export -f _apicall torrents sync



case $1 in
cache)
	cat $(ls -1t /tmp/qbtlib.sh.cache_* | head -n1) | zstdmt -d
	;;
last)
	torrents info -G --data "sort=added_on" | \
		jq -r '.[] | [ .hash, .category, .content_path ] | @tsv' | \
		zstdmt --adapt | tee $tmp | zstdmt -d
	;;
active)
	torrents info -G \
		--data "sort=added_on" \
		--data "filter=active" | \
		jq -r '.[] | [ .hash, .category, .content_path ] | @tsv'
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
countries)
	parallel -j32 'sync torrentPeers -G --data "hash={}" | jq -r ".peers | to_entries | .[].value | .country"'
	;;

# jq's floor should be embedded in an arrray.
# echo '{"mass": 188.72, "shit": 100}' | jq ' [ [.mass|floor] , .shit ] | flatten'
# looks ugly
monitor)
	torrents info -G \
		--data "sort=upspeed" \
		--data "filter=active" | \
		jq -r '.[] | [ .category, .name, .upspeed/1024/1024, .progress*100 ] | @tsv' | \
		column --table -N category,name,upspeed,completed -s$'\t'
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

esac
