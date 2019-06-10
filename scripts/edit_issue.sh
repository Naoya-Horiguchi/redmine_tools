# Usage:
#   - edit_issue.sh             // 新規 issue の生成する
#   - edit_issue.sh id [...]    // 指定した id の issue を更新する
#   - edit_issue.sh file [...]  // 指定した file ベースで issue を生成・更新する
#
# Options:
#   -f: force update (FORCE_UPDATE)
#   -n: no download (using local edit cache) (NO_DOWNLOAD)

# TMPD=$(mktemp -d)
TMPD=$RM_CONFIG/edit_memo
mkdir -p $TMPD
THISDIR=$(readlink -f $(dirname $BASH_SOURCE))

. $THISDIR/utils.sh

# TODO: 複数の issue を同時に編集する手段
# TODO: チケット削除
# TODO: ファイルからの入力
# TODO: 編集時刻のタイムクロック記録
# TODO: 新規作成のときと更新のときで必要になる確率が高い凡例が異なるため、順序を変更する.
# TODO: オプションの充実

if [ "$#" -eq 0 ] ; then
	mkdir -p $TMPD/new
	if [ ! "$NO_DOWNLOAD" ] ; then
		generate_issue_template
	fi
	edit_issue new || exit 1
	create_issue new
else
	for issueid in $@ ; do
		# TODO: 時刻記録
		mkdir -p $TMPD/$issueid
		if [ ! "$NO_DOWNLOAD" ] ; then
			date +%Y-%m-%dT%H:%M:%SZ > $TMPD/$issueid/timestamp
			download_issue $issueid
		fi
		edit_issue $issueid || continue
		# TODO: サーバ上の更新比較、必要に応じて警告
		tstamp_saved=$(date -d $(cat $TMPD/$issueid/timestamp) +%s)
		tstamp_tmp=$(curl ${INSECURE:+-k} -s "$RM_BASEURL/issues.json?issue_id=${issueid}&key=${RM_KEY}&status_id=*" | jq -r ".issues[].updated_on")

		if [[ "$tstamp_saved" > "$tstamp_tmp" ]] || [ "$FORCE_UPDATE" ] ; then
			upload_issue $issueid
		else
			echo "update conflict, need to resolve conflict and manually upload it with NO_DOWNLOAD option enabled."
		fi
	done
fi
