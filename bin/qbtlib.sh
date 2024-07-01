# usage:
# bash qbtlib.sh last | grep Отечественная | cut -f1 | bash qbtlib.sh resume
# bash qbtlib.sh active | cut -f1 | bash qbtlib.sh countries | sort | uniq -c | sort -n
# watch "bash qbtlib.sh monitor | column --table -N category,name,upspeed -s$'\t' | tail -n50"

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
monitor)
	torrents info -G \
		--data "sort=upspeed" \
		--data "filter=active" | \
		jq -r '.[] | [ .category, .name, .upspeed/1024/1024 ] | @tsv'
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
esac
