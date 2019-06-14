# LIMIT
# PROJECT: project filter
# TRACKER: tracker filter

TMPD=$RM_CONFIG/edit_memo
mkdir -p $TMPD
THISDIR=$(readlink -f $(dirname $BASH_SOURCE))

. $THISDIR/utils.sh

[ ! "$LIMIT" ] && LIMIT=10

curl -s -k "$RM_BASEURL/issues.json?key=${RM_KEY}&limit=$LIMIT&sort=updated_on:desc" | jq -r -c '.issues[] | [.id, .updated_on, .project.name, .status.name, .subject] | @tsv' > $TMPD/.recent_changes

IFS=$'\t'
while read id update pjname status subj ; do
	echo -e "$id\t$(date -d $update +%y%m%d_%H%M)\t$pjname\t$status\t$subj"
done < "$TMPD/.recent_changes" | column -t -s $'\t'
