# PROJECT: project filter
# TRACKER: tracker filter

TMPD=$RM_CONFIG/edit_memo
mkdir -p $TMPD
THISDIR=$(readlink -f $(dirname $BASH_SOURCE))

. $THISDIR/utils.sh

LIMIT=10

# TODO: タイムスタンプのフォーマットの改善
curl -s -k "$RM_BASEURL/issues.json?key=${RM_KEY}&limit=$LIMIT&sort=updated_on:desc" | jq -r -c '.issues[] | [.id, .updated_on, .project.name, .status.name, .subject] | @tsv' | column -t -s $'\t'
