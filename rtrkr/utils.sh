# download xml database
qbtlib.sh add_rtrkr 5591249 -F savepath=/mnt/all/rtrkr -F paused=false

# xml2tsv
cat $(ls -t /mnt/huanan/all/rtrkr/rutracker-*.xml.xz | tail -n1) \
        | xz -d \
        | grep -e '<title>' -e '<torrent ' -e '<forum ' \
        | tr '\n' '\r' \
        | sed 's/\r </ </g' \
        | tr '\r' '\n' \
        | perl -pe 's/.*torrent id="(\d+)" registred_at="(.+)" size="(\d+)".*<title>(.*)<\/title>.*hash="(\w+)".*forum id="(\d+)">(.*)<\/forum>.*/$1\t$2\t$3\t$4\t$5\tfid:$6\t$7/' \
        | pv -rabt \
        >rtrkr.tsv


# compute size of each forum
$ time cat *.tsv \
    | cut -f6,7 \
    | sort -u -k2 \
    | hwloc-bind core:all -- parallel --colsep=$'\t' 'b=$(cat *.tsv | grep {1} | cut -f3 | paste -sd+ | bc); pretty=$(echo $b bytes | qalc --set "color 0" | grep B); printf "%s\t%s\n" "$pretty" {2}' \
    | qbtlib.sh table \
    | sort -n \
    > forumstat.txt

real    1m30.669s
user    17m28.116s
sys     39m59.188s
