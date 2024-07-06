
#removes stuff like '(Acoustik rock,Psychedelic)[MB] [16-44.1]' from the beginning of a directory name (aka topic name)

set -ue

nono() {
    cd "$1"
    mkdir -p .nometa
    ls -1 | \
        grep -v nometa | \
        perl -pe 's/^((\([^\)]+\)|\s|(\[[^\]]+\])))*\s*(.*)/$4/' | \
        parallel --lb 'ln -r -s *{} .nometa/{}'
}
export -f nono

cd forum
ls -1d *музыка* *оцифровки* | sort -u | parallel --lb -j2 nono

