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
LOCALTICKET=

. $THISDIR/utils.sh

# TODO: 編集時刻のタイムクロック記録
# TODO: 新規作成のときと更新のときで必要になる確率が高い凡例が異なるため、順序を変更する.
# TODO: オプションの充実
# TODO: 添付の実装
# TODO: watcher の実装
# TODO: 複数の issue を同時に編集する手段
# TODO: チケット削除
# TODO: ファイルからの入力
# TODO: oneshot task の定義 (一回編集して終わり、という短期タスクもある)

if [ "$#" -eq 0 ] ; then
	issueid=new
elif [ "$1" == "-l" ] ; then
	# TODO: local task (クロック管理等のために、擬似的なタスクを用意する、
    # 通常タスクは成果物や予定管理、Epic の場合は情報共有のために存在して
    # いるが、メールチェックや雑用などはクロック記録目的であるので redmine
    # に登録する必要性がない)
	LOCALTICKET=true
	if [ "$2" ] ; then
		issueid=$2
	else
		issueid=LOCAL_$(date +%y%d%m_%H%M%S)
	fi
else
	issueid=$1
fi
mkdir -p $TMPD/$issueid

prepare_draft_file $issueid || exit 1
update_issue $issueid || exit 1
