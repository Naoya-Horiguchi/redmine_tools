if [ ! "$RM_BASEURL" ] ; then
	echo you need setup RM_BASEURL/RM_KEY
	exit 1
fi

STEP=100
REQUESTBASE="$RM_BASEURL/issues.json?key=${RM_KEY}&status_id=*"
TOTALCOUNT=$(curl ${INSECURE:+-k} -s ${REQUESTBASE} | jq .total_count)
PAGES=$[($TOTALCOUNT - 1) / $STEP + 1]

echo TOTALCOUNT: $TOTALCOUNT
echo PAGES: $PAGES

[ ! "$TOTALCOUNT" ] && exit 1

TMPD=$(mktemp -d)
FILES=
for i in $(seq 0 $[PAGES-1]) ; do
	curl ${INSECURE:+-k} -s "${REQUESTBASE}&offset=$[i*$STEP]&limit=$STEP" > $TMPD/page.$i.json || exit 1
	FILES="$FILES $TMPD/page.$i.json"
done

jq 'reduce inputs as $i (.; .issues += $i.issues)' $FILES > $TMPD/list.json

# 最新版のアップデートは更新が成功したときだけにしたい。
# サーバ側の更新は日時比較からのみ知ることができる。
#
#   if チケットの最新の更新時 > 前回のアップデート成功時刻
#     サーバ側にアップデータがあるので、アップロードせず警告を表示
#     終了
#   
#   (当該コンフリクトの解消)
#   
#   for each org entry
#     if ローカルの更新チェック
#       更新対象
#     fi
#   すべて更新に成功したら、最終アップデート時刻を更新
#
# あるいはシンプルに以下のロジックでよいかもしれない。
#
#   for each ticket
#     if ローカルとサーバ上の内容に差がある
#       if (最終アップデート時刻がない) or (サーバ上の最終更新時刻 > 最終アップデート時刻)
#         警告
#       else
#         アップロード
#         アップデート時刻更新 (失敗以外)
#       end
#     end
#   end
#
# 最終アップデート時刻をエントリごとに管理しないと、途中で間欠的にアップロードに
# 失敗したときとかにアップデート時刻情報が当てにならなくなる。
cp $TMPD/list.json $RM_CONFIG/issues.json
# date +%Y-%m-%dT%H:%M:%SZ > $RM_CONFIG/issues.timestamp


# cat $TMPD/list.json | jq -r .
# cat $TMPD/list.json | jq -r .issues[0]
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, assigned_to, estimated_hours}'
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, estimated_hours, custom_fields}'
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, estimated_hours, customid: .custom_fields[0].value}'
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, estimated_hours, customid: .custom_fields[0].value} | [.customid, .id] | @csv' | grep -v ^, | tr -d \"
# cat $TMPD/list.json | jq -r '.issues[] | {subject, id, customid: .custom_fields[0].value}' 
