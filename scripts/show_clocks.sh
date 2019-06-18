THISDIR=$(readlink -f $(dirname $BASH_SOURCE))
. $THISDIR/utils.sh

TMPD=$(mktemp -d)

# any format supported by date command (-d option)
START=$1
END=$2

[ ! "$START" ] && START=$(date --date="today 0:00" +%Y/%m/%d)
[ ! "$END" ] && END=$(date --date="tomorrow 0:00" +%Y/%m/%d)

echo "Clock during [$START, $END)"
START=$(date --date="$START" +%s)
END=$(date --date="$END" +%s)
echo "Clock during [$START, $END)"

for f in $(find $RM_CONFIG/edit_memo -name .clock.log) ; do
	id=$(basename $(dirname $f))
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
	echo $id,$[sum/60] >> $TMPD/summary
done
cat $TMPD/summary | column -t -s , | sort -k2n
