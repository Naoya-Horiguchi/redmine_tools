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

# TODO: 編集時刻のタイムクロック記録
# TODO: 新規作成のときと更新のときで必要になる確率が高い凡例が異なるため、順序を変更する.
# TODO: オプションの充実
# TODO: 添付の実装
# TODO: watcher の実装
# TODO: 複数の issue を同時に編集する手段
# TODO: チケット削除
# TODO: ファイルからの入力

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
		CLOCK_START=$(date --iso-8601=seconds)
		if [ ! "$NO_DOWNLOAD" ] ; then
			echo "Downloading ..."
			echo $CLOCK_START > $TMPD/$issueid/timestamp
			download_issue $issueid || continue
		fi
		echo "IN $CLOCK_START" >> $TMPD/$issueid/.clock.log
		edit_issue $issueid
		RET=$?
		echo "OUT $(date --iso-8601=seconds)" >> $TMPD/$issueid/.clock.log
		if [ "$RET" -ne 0 ] ; then
			continue
		fi
		# TODO: サーバ上の更新比較、必要に応じて警告
		tstamp_saved="$(date -d $(cat $TMPD/$issueid/timestamp) +%s)"
		tstamp_tmp=$(curl ${INSECURE:+-k} -s "$RM_BASEURL/issues.json?issue_id=${issueid}&key=${RM_KEY}&status_id=*" | jq -r ".issues[].updated_on")
		tstamp_tmp="$(date -d $tstamp_tmp +%s)"

		if [[ "$tstamp_saved" > "$tstamp_tmp" ]] || [ "$FORCE_UPDATE" ] ; then
			upload_issue $issueid
		else
			echo "The ticket $issueid was updated on server-side after you downloaded it into local file."
			echo "So there's a conflict, you need to resolve conflict and manually upload it with options FORCE_UPDATE=true and NO_DOWNLOAD=true."
		fi
	done
fi
