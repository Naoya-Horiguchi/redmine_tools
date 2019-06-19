THISDIR=$(readlink -f $(dirname $BASH_SOURCE))
. $THISDIR/utils.sh

TMPD=$(mktemp -d)

# any format supported by date command (-d option)
START=$1
END=$2

[ ! "$START" ] && START="$(date --date="today 0:00" +%Y/%m/%d)"
[ ! "$END" ] && END="$(date --date="$START 23:59" --iso-8601=seconds)"

echo "Clock during [$START, $END)"
START=$(date --date="$START" +%s)
END=$(date --date="$END" +%s)

for f in $(find $RM_CONFIG/edit_memo -name .clock.log) ; do
	dir=$(dirname $f)
	id=$(basename $dir)
	subject="$(grep -i ^#\+subject: $dir/draft.md | sed 's|^#+subject: *||i')"
	project="$(grep -i ^#\+project: $dir/draft.md | sed 's|^#+project: *||i')"

	sum=0
	# filter out with file timestamp
	IFS=$'\n'
	for line in $(cat $f) ; do
		cin=$(echo $line | cut -f1 -d' ')
		cout=$(echo $line | cut -f2 -d' ')
		tin=$(date -d $cin +%s)
		tout=$(date -d $cout +%s)
		[ "$tin"  -ge "$END"   ] && continue
		[ "$tout" -le "$START" ] && continue
		[ "$tin"  -le "$START" ] && tin=$START
		[ "$tout" -ge "$END"   ] && tout=$END

		[ ! "${sum[$id]}" ] && sum[$id]=0
		sum=$[$sum + $tout - $tin]
	done
	echo -e "$id\t$[sum/60]\t$project\t$subject" >> $TMPD/summary
done
cat $TMPD/summary | column -t -s $'\t' | sort -k2n
