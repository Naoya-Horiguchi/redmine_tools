# LIMIT
# INCLUDE_STATUS
# ASSIGNED
# PROJECT: project filter
# TRACKER: tracker filter

TMPD=$RM_CONFIG/edit_memo
mkdir -p $TMPD
THISDIR=$(readlink -f $(dirname $BASH_SOURCE))

. $THISDIR/utils.sh

[ ! "$LIMIT" ] && LIMIT=10

if [ "$INCLUDE_STATUS" ] ; then
	STATUS_OPT="&status_id=$INCLUDE_STATUS"
fi

if [ "$ASSIGNED" ] ; then
	ASSIGNED_OPT="&assigned_to_id=$ASSIGNED"
fi

curl -s -k "$RM_BASEURL/issues.json?key=${RM_KEY}${STATUS_OPT}${ASSIGNED_OPT}&limit=$LIMIT&sort=updated_on:desc" | jq -r -c '.issues[] | [.id, .updated_on, .project.name, .status.name, .subject] | @tsv' > $TMPD/.recent_changes

IFS=$'\t'
while read id update pjname status subj ; do
	echo -e "$id\t$(date -d $update +%y%m%d_%H%M)\t$pjname\t$status\t$subj"
done < "$TMPD/.recent_changes" | column -t -s $'\t'
