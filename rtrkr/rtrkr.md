## crude rutracker interface

`add_rtrkr` depends of `rtrkr_curl.sh` script in PATH.
it is obtained from chrome's developer tools, network tab, copy as curl for a download request.
remove url, referer, form_token and add `-s -L -x socks5://whatever $@`

`rutracker-*.xml` in compressed form is from topic number 5591249


prepare xml fail as tsv
```
$ cat rutracker-*.xml \
	| grep -e '<title>' -e '<torrent ' -e '<forum ' \
	| tr '\n' '\r' \
	| sed 's/\r </ </g' \
	| tr '\r' '\n' \
	| perl -pe 's/.*torrent id="(\d+)" registred_at="(.+)" size="(\d+)".*<title>(.*)<\/title>.*hash="(\w+)".*forum id="(\d+)">(.*)<\/forum>.*/$1\t$2\t$3\t$4\t$5\tfid:$6\t$7/' \
	| pv -rabt >id.date.size.title.hash.forumid.forumname.tsv
 798MiB 0:00:52 [15.2MiB/s] [15.2MiB/s]
```


list all forum ids with names (runs for about a minute)
```
cat id.date.size.title.hash.forumid.forumname.tsv \
	| cut -f6,7 \
	| sort -u -k2 \
	| qbtlib.sh table \
	| less
```


count number of bytes in one forum's torrents

```
$ cat id.date.size.title.hash.forumid.forumname.tsv | grep fid:2301 | cut -f3 | paste -sd+ | bc
11277788664982
```


missing torrents from certain forum
```
cat id.date.size.title.hash.forumid.forumname.tsv \
	| grep fid:2301 \
	| grep -v -i -F -f <(qbtlib.sh cache1)
```


their size
```
$ echo $(cat id.date.size.title.hash.forumid.forumname.tsv | grep fid:2301 | grep -v -i -F -f <(qbtlib.sh cache1) | cut -f3 | paste -sd+ | bc) bytes | qalc
> 9545414628914 bytes

  9545414628914 bytes ≈ 9.545414629 TB
```


download and add missing torrents from forum id 2301 with names containig word `blues`
```
$ cat id.date.size.title.hash.forumid.forumname.tsv \
	| grep fid:2301 \
	| cut -f1,4,5 \
	| grep -i blues \
	| grep -v -i -F -f <(qbtlib.sh cache1) \
	| cut -f1 \
	| parallel --tag -j4 'qbtlib.sh add_rtrkr {} -F savepath=/mnt/all/music/keep/{}'
```

---

todo: parse deleted torrents
```
$ cat rutracker-*.xml | grep 'del/>' | wc -l
25680

```

sometimes tracker sends `<center><br><br>Error: attachment data not found</center>`
instead of torrent file. qbt expectably fails `Error: 'filename.torrent' is not a valid torrent file.`
