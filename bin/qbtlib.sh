# usage:
# bash qbtlib.sh last | grep Отечественная | cut -f1 | bash qbtlib.sh resume

tmp=/tmp/qbtlib.sh.cache_$(date +%F_%R).zst

_apicall() {
	s=--silent
	#s=--verbose
	set -vx
	curl $s \
		http://${QBT_HOST:-localhost:8283}/api/v2/torrents/$1 \
		"${@:2}"
	set +vx
}

case $1 in
cache)
	cat $(ls -1t /tmp/qbtlib.sh.cache_* | head -n1) | zstdmt -d
	;;
last)
	_apicall info -G --data "sort=added_on" | \
		jq -r '.[] | [ .hash, .category, .content_path ] | @tsv' | \
		zstdmt --adapt | tee $tmp | zstdmt -d
	;;
resume)
	hashes=$(paste -sd\|)
	_apicall resume -X POST --data "hashes=$hashes"
	;;
recheck)
	hashes=$(paste -sd\|)
	_apicall recheck -X POST --data "hashes=$hashes"
	;;
esac
