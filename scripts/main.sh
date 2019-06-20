#!/bin/bash
#
# Usage:
#   - redmine [global options] <subcmd> [options]
#
# Global options (GLOBAL_VARIABLE)
#   -c config_file  specify config file including set of configurations
#   -d dir          directory to store config and ticket cache (RM_CONFIG)
#   -u base_url     base URL of target RedMine server (RM_BASEURL)
#   -k api_key      API key to access to the RedMine (RM_KEY)
#   -f format       markup language used by the RedMine (textile or markdown: RM_FORMAT)
#   -e editor       your text editor (EDITOR)
#   --insecure      skip verification of the certificate for HTTPS connection (INSECURE)
#   --legend        open with EDITOR with legend list aside from draft.md (RM_LEGEND)
#
# Subcommands:
#   list [options]
#     -n limit      number of ticket to list (default: 25)
#     -a user_id    filter ticket with given user (user ID or "me")
#     -c            include closed tickets
#     -l            include local tickets
#
#   new [options]
#     -l            local ticket
#
#   show [options] <ticket_id>
#
#   edit [options] <ticket_id>
#     -f            force update (upload draft.md even if there's update on server: FORCE_UPDATE)
#     -n            no download and edit with local cache (NO_DOWNLOAD)
#
#   delete [options] <ticket_id>
#
#   clock [options] [start_date] [end_date]  # show clock summary
#
#   open [options] <ticket_id>               # open with browser
#
#   help <subcommand>
#
#
# Planned features:
#   - convert local ticket to RedMine ticket (and vice versa)
#   - handle attachment
#   - clock analysis
#   - server health check
#   - collect server meta info
#   - support preview for draft.md
#   - event filter (extracting tickets which changed status during given period)
#   - support local RedMine (using docker)
#   - status change if done_ratio is changed
#   - create sub-ticket or related ticket from a given ticket
#   - notify if the ticket is already open
#

REAL_SOURCE=$(readlink -f $BASH_SOURCE)
THISDIR=$(readlink -f $(dirname $REAL_SOURCE))
. $THISDIR/utils.sh

TMPD=$RM_CONFIG/edit_memo
mkdir -p $TMPD

while [[ $# -gt 0 ]] ; do
	key="$1"
	case $key in
		-c|--config-file)
			source $2
			shift 2
			;;
		-d|--data-dir)
			RM_CONFIG="$(readlink -f $2)"
			shift 2
			;;
		-u|--base-url)
			RM_BASEURL="$2"
			shift 2
			;;
		-k|--api-key)
			RM_KEY="$2"
			shift 2
			;;
		-f|--format)
			RM_FORMAT="$2"
			shift 2
			;;
		-e|--editor)
			EDITOR="$2"
			shift 2
			;;
		--insecure)
			INSECURE=true
			shift 1
			;;
		--legend)
			RM_LEGEND=true
			shift 1
			;;
		*) # end of global options
			break
			;;
	esac
done

SUBCMD="$1"
shift

[ ! "$SUBCMD" ] && SUBCMD=help

if [ ! -e "$THISDIR/cmd/$SUBCMD" ] ; then
	echo "subcommand $SUBCMD not supported" >&2
	exit 1
fi

. $THISDIR/cmd/$SUBCMD

# TODO: コマンド体型の構築
# TODO: 編集時刻のタイムクロック記録
# TODO: 新規作成のときと更新のときで必要になる確率が高い凡例が異なるため、順序を変更する.
# TODO: オプションの充実
# TODO: 添付の実装
# TODO: watcher の実装
# TODO: 複数の issue を同時に編集する手段
# TODO: チケット削除
# TODO: ファイルからの入力
# TODO: oneshot task の定義 (一回編集して終わり、という短期タスクもある)
