#!/bin/bash

#set -u

export PATH=$BASH_SOURCE:$PATH

die() {
	echo $@
	exit 1
}

helpall() {
	argn=$(grep -P '^[\w\.]+\)' ${BASH_SOURCE[0]} | wc -l)
	helpn=$(grep -w ' -n "$help" ] && die ' ${BASH_SOURCE[0]} | grep -v helpn | wc -l)
	[ $argn -ne $helpn ] && echo incomplete help $helpn of $argn args && exit -1

	cat ${BASH_SOURCE[0]} | grep -P '^[\w\.]+\)' | tr -d ')' | \
		parallel --tag -k rtrckr.sh help | qbtlib.sh table

	cat << EOF

examples:

rtrckr.sh find ubuntu bdremux
rtrckr.sh ifind ubuntu bdremux | parallel --tag -j4 'rtrckr.sh download {} -F savepath=/mnt/all/film -F category= -F tags=rtrckr -F paused=false'
rtrckr.sh frompage https://rutracker.org/forum/viewtopic.php?t=6012098 | parallel -j4 'rtrckr.sh download {} -F savepath=/mnt/all/mult/FilmScan -F category=mult/fscan -F paused=false'
EOF

	head -n1 $tsv
	echo 'id time size title hash fid forum'
	echo '1  2    3    4     5    6   7    '
}

tsv=$(dirname $(readlink "${BASH_SOURCE[0]}"))/rtrckr/rtrckr.tsv

cmd=$1
shift
if [ "$cmd" = "help" ]; then
	help=1
	cmd=$1
	shift
fi

[ -z "$cmd" ] && helpall && die

case $cmd in
grep)
	[ -n "$help" ] && die 'find patterns in tsv file'
	[ -s $tsv ] || die "error: no tsv file ($tsv), see xml2tsv.sh"
	if [ -z "$1" ]; then
		cat $tsv
	else
		rtrckr.sh grep ${@:2} | grep -i "$1"
	fi
	;;

find)
	[ -n "$help" ] && die 'find torrents, columns: size in GiB, name, forum'
	#cat $tsv | grep $@ \
	rtrckr.sh grep $@ \
		| cut -f1,3,4,6,7 \
		| sort -k2 -n \
		| awk -F $'\t' ' BEGIN {OFS = FS} {$2 = $2/1024/1024/1024; print}' # \
		#| qbtlib.sh table #-T3

	;;
ifind)
	[ -n "$help" ] && die 'like find but output is only id, useful for `rtrckr.sh download`'
	rtrckr.sh grep $@ \
		| cut -f1
	;;

download)
	[ -n "$help" ] && die 'download torrent with id `arg1` and add it to qbt. optional args -F savepath= -F category= -F tags= -F paused=true'
	id=$1
	# TODO: use permanent ~/.cache and warn on very old files?
	tcache=/tmp/qbtlib.cache.$id.torrent
	[ -s $tcache ] || rtrckr.sh curl https://rutracker.org/forum/dl.php?t=$id >$tcache
	qbtlib.sh add $tcache ${@:2}
	;;

frompage)
	[ -n "$help" ] && die 'extract torrent ids from links from page `arg1`'
	rtrckr.sh curl $1 | \
	iconv -f cp1251 | \
	fq -d html -o array=true -r '.. | select(.[0] == "a" and (.[1].href|test("viewtopic.php.t=[0-9]+$")))? .[1].href' |
	sed 's/.*t=\([0-9]\+\).*/\1/'
	;;

xml2tsv)
	[ -n "$help" ] && die 'update tsv database from xml file `arg1`'
	#last file from personal location if no argument
	xml=${1:-$(ls -t /mnt/hall/rtrkr/rutracker-*.xml.xz | tail -n1)}

	cat $xml \
		| xz -d \
		| pv -N xml -crabt \
		| grep -e '<title>' -e '<torrent ' -e '<forum ' \
		| tr '\n' '\r' \
		| sed 's/\r </ </g' \
		| tr '\r' '\n' \
		| pv -N filtered -crabt \
		| perl -pe 's/.*torrent id="(\d+)" registred_at="(.+)" size="(\d+)".*<title>(.*)<\/title>.*hash="(\w+)".*forum id="(\d+)">(.*)<\/forum>.*/$1\t$2\t$3\t$4\t$5\tfid:$6\t$7/' \
		| pv -N tsv -crabt \
		>$tsv
	;;

curl)
	[ -n "$help" ] && die 'invoke rtrkr_curl.sh'
	which rtrkr_curl.sh >/dev/null || die 'rtrkr_curl.sh not fount, see README.md'
	rtrkr_curl.sh $@
	;;

*)
	die no such command
	;;

esac

set +vx


#curl \
#    $@ \
#    -s -S -L -4 \
#  -x socks5://127.0.0.1:5055 \
#  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
#  -H 'accept-language: en-US,en;q=0.9' \
#  -H 'cache-control: max-age=0' \
#  -H 'content-type: application/x-www-form-urlencoded' \
#  -H 'cookie: bb_guid=...' \
#  -H 'origin: https://rutracker.org' \
#  -H 'priority: u=0, i' \
#  -H 'sec-ch-ua: "Not/A)Brand";v="8", "Chromium";v="126", "Google Chrome";v="126"' \
#  -H 'sec-ch-ua-mobile: ?0' \
#  -H 'sec-ch-ua-platform: "Linux"' \
#  -H 'sec-fetch-dest: document' \
#  -H 'sec-fetch-mode: navigate' \
#  -H 'sec-fetch-site: same-origin' \
#  -H 'sec-fetch-user: ?1' \
#  -H 'upgrade-insecure-requests: 1' \
#  -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
