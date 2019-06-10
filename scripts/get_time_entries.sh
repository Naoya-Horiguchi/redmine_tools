if [ ! "$RM_BASEURL" ] ; then
	echo you need setup RM_BASEURL/RM_KEY
	exit 1
fi

STEP=100
REQUESTBASE=$RM_BASEURL/time_entries.json?key=$RM_KEY
TOTALCOUNT=$(curl -s ${REQUESTBASE} | jq .total_count)
PAGES=$[($TOTALCOUNT - 1) / $STEP + 1]

echo TOTALCOUNT: $TOTALCOUNT
echo PAGES: $PAGES

TMPD=$(mktemp -d)
FILES=
for i in $(seq 0 $[PAGES-1]) ; do
	echo curl -s "${REQUESTBASE}&offset=$[i*$STEP]&limit=$STEP"
	curl -s "${REQUESTBASE}&offset=$[i*$STEP]&limit=$STEP" > $TMPD/page.$i.json
	FILES="$FILES $TMPD/page.$i.json"
done

jq 'reduce inputs as $i (.; .time_entries += $i.time_entries)' $FILES > $TMPD/list.json

cp $TMPD/list.json $RM_CONFIG/time_entries.json

# cat $TMPD/list.json | jq -r .
# cat $TMPD/list.json | jq -r .issues[0]
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, assigned_to, estimated_hours}'
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, estimated_hours, custom_fields}'
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, estimated_hours, customid: .custom_fields[0].value}'
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, estimated_hours, customid: .custom_fields[0].value} | [.customid, .id] | @csv' | grep -v ^, | tr -d \"
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, customid: .custom_fields[0].value}' 
