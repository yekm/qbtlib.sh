
# pixz -dc rutracker-20240127.xml.xz | grep -e '<title>' -e '<torrent ' -e '<forum ' >tttf.txt
# curl http://localhost:8283/api/v2/torrents/info | jq -r '.[] | [.content_path, .hash] | @tsv' | parallel --eta bash mkrtrkr.sh

# cd "$(cat dir.list | grep -i -w sabbath | fzf +x)"

set -eu
cpath=$(echo "$@" | cut -f1)
hash=$(echo "$@" | cut -f2)

echo "$cpath ::: $hash"

#title hash forum
thf=$(grep -C1 -i $hash tttf.txt)

#title=$(echo "$thf" | head -n1 | sed 's,</\?title>,,g; s/^ //; s,/,-,g')
title=$(echo "$thf" | head -n1 | perl -pe 's|</?title.*?>||g;  s|<!\[CDATA\[||; s|\]\]||; s|^ ||; s|/|-|g')
forum=$(echo "$thf" | tail -n1 | perl -pe 's|</?forum.*?>||g; s|<!\[CDATA\[||; s|\]\]||; s|^ ||; s|/|-|g')


ft="forum/$forum/$title"
[ -d "$ft" ] && exit
mkdir -p "$ft"
ln -v -s -r "$cpath" -t "$ft"

