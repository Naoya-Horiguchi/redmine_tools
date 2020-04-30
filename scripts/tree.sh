show_task_subtree() {
	local taskid=$1
	local depth=$2
	local parent_closed=$3
	local closed=
	local childid=

	[ ! "$parent_closed" ] && parent_closed=true
	if status_closed "${STATUS_TABLE[$taskid]}" ; then
		closed=true
	else
		closed=false
	fi

	if [ "$RM_SHOW_CLOSED" = "false" ] ; then
		if [ "$closed" == true ] ; then
			return 0
		fi
	elif [ ! "$RM_SHOW_CLOSED" ] ; then
		# by default a closed ticket is visible if it's parent ticket is open.
		if [ "$closed" == true ] && [ "$parent_closed" == true ] ; then
			return 0
		fi
	fi

	printf "%$[depth*2]s%-4s %s%s\n" "" "$taskid" "$(get_meta_part $taskid)" "${SUBJECT_TABLE[$taskid]}"
	for childid in ${SUBTASK_TABLE[$taskid]} ; do
		show_task_subtree $childid $[depth+1] $closed
	done
}

show_task_tree() {
	local tid=
	local depth=$1
	[ ! "$depth" ] && depth=1

	cat $TMPDIR/top_level_tasks | while read line ; do
		show_task_subtree $line $depth
	done
}

# 関連タイプを取り出す。
# jq -r ".issues[].relations[] | [.id, .issue_id, .issue_to_id, .relation_type] | @tsv" $DATA | sort | uniq
# jq -r ".relations[] | [.id, .issue_id, .issue_to_id, .relation_type] | @tsv" $TMPDIR/pj15 | sort -k1n | uniq
# jq -r ". | [.id, .issue_id, .issue_to_id, .relation_type] | @tsv" $TMPDIR/pj15
# head $TMPDIR/pj15
# exit
# jq -r ". | [.id, .issue_id, .issue_to_id, .relation_type] | @tsv" $TMPDIR/pj15 | sort | uniq

# TODO: プロジェクト内のタスクの表示順序、関連がなければ ID 順、あればそれに応じた順番に並べることになる。
show_project_task_tree() {
	local projectid=$1
	local depth=$2
	[ ! "$depth" ] && depth=0

	jq ".issues[] | select(.project.id == $projectid)" $DATA > $TMPDIR/pj$projectid

	printf "%$[depth*2]s%-4s %s\n" "" "PJ$projectid" "$(project_id_to_name $projectid)" >> $TMPDIR/out
	get_subtask_table $TMPDIR/pj$projectid
	get_relation_table $TMPDIR/pj$projectid
	# echo ${!RELATION_TABLE[@]}
	# echo ${RELATION_TABLE[*]}
	show_task_tree $[depth+1]
}

show_ticket_subtree() {
	local tid="$1"
	local projectid="$(issueid_to_pjid $tid)"

	jq ".issues[] | select(.project.id == $projectid)" $DATA > $TMPDIR/pj$projectid
	printf "%$[depth*2]s%-4s %s\n" "" "PJ$projectid" "$(project_id_to_name $projectid)"
	get_subtask_table $TMPDIR/pj$projectid
	get_relation_table $TMPDIR/pj$projectid
	show_task_subtree "$tid" 1
}

project_id_to_name() {
	local pjid=$1
	local name="$(jq -r ".projects[] | select(.id == $pjid) | .name" $RM_CONFIG/projects.json)"

	if [ ! "$name" ] ; then
		echo "project id $pjid is not found in $RM_CONFIG/projects.json" >&2
		exit 1
	fi
	echo "$name"
}

__show_task_subproject() {
	local pjid=$1
	local depth=$2
	local subpjid=

	show_project_task_tree $pjid $[depth] >> $TMPDIR/out
	for subpjid in ${SUBPJ_TABLE[$pjid]} ; do
		__show_task_subproject $subpjid $[depth+1]
	done
}

show_project_tree() {
	local pjid=$1
	local depth=0
	local subpjid=

	__show_task_subproject $pjid 0
}

diff_check() {
	local id=$1
	local diff=$2
	local before=
	grep -e "^+ *$"
}

find_new_parent() {
	local issueid="$1"

	local parent=$(grep "^+$issueid parenttask" $TMPDIR/pjtree.diff | cut -f3 -d' ')
	[ "$parent" ] && echo $parent && return
	parent=$(grep "^-$issueid parenttask" $TMPDIR/pjtree.diff | cut -f3 -d' ')
	[ "$parent" ] && echo null && return
	# unchange
}

find_new_project() {
	local issueid="$1"

	local project=$(grep "^+$issueid newpj" $TMPDIR/pjtree.diff | cut -f3 -d' ')
	[ "$project" ] && echo $project && return
	# unchange
}

# TODO: support project update
find_new_parent_project() {
	true
}

update_pjtree_ticket() {
	local issueid=$1
	local newline="$2"
	local oldline="$3"
	local metafield="$(echo "$newline" | awk -F'[><]' '{print $2}')"
	local tracker="$(echo $metafield | cut -f1 -d\|)"
	local status="$(echo $metafield | cut -f2 -d\|)"
	local done_ratio="$(echo $metafield | cut -f3 -d\|)"
	# TODO: 不完全、タイトルの先頭に () がある場合と区別できないといけない
	local newrelations="$(echo "$newline" | sed 's/.*(\([0-9>|=#,-]\+\)).*/\1/')"
	local oldrelations="$(echo "$oldline" | sed 's/.*(\([0-9>|=#,-]\+\)).*/\1/')"
	local newrel="$(echo "$newline" | awk -F'[)(]' '{print $2}' | tr ',' ' ')"
	local newrel2=
	local oldrel="$(echo "$oldline" | awk -F'[)(]' '{print $2}' | tr ',' ' ')"
	local oldrel2=

	local subject="$(echo "$newline" | cut -f2- -d \> | sed 's/^ *//')"
	if [ "$newrelations" != "$newline" ] ; then # new line has relations
		subject="$(echo "$newline" | cut -f2- -d \) | sed 's/^ *//')"
	fi

	# echo "newrelations: [$newrelations]"
	# echo "newline: [$newline]"
	# echo "oldrelations: $oldrelations"
	# echo "oldline: $oldline"
	# echo "subject: $subject"

	# TODO: 不完全、関連がある場合に区別できない
	# TODO: changes on relationship don't change update_on of the related issues
	if [ "$newrelations" != "$newline" ] ; then
		local subject="$(echo $newline | cut -f2- -d \) | sed 's/^ *//')"

		# ignore unchanged relation
		for rel in $newrel ; do
			if echo "$oldrel" | grep -q -w "$rel" ; then
				continue
			fi
			newrel2="$newrel2 $rel"
		done
		[ "$newrel2" ] && echo "new relations: $newrel2"

		for relstring in $newrel2 ; do
			generate_relation_json "$issueid" "$relstring" > $TMPDIR/upload_relation.json
			create_relation $issueid $TMPDIR/upload_relation.json || exit 1
			# update opponent issue
			( update_local_cache_task ${relstring:1} ) &
		done
	fi

	if [ "$oldrelations" != "$oldline" ] ; then
		for rel in $oldrel ; do
			if echo "$newrel" | grep -q -w "$rel" ; then
				continue
			fi
			oldrel2="$oldrel2 $rel"
		done
		[ "$oldrel2" ] && echo "old relations: $oldrel2"

		for relstring in $oldrel2 ; do
			local relid=$(get_relation_from_server "$issueid" "$relstring")
			if [ "$relid" ] ; then
				echo "delete_relation $relid"
				delete_relation "$relid" || exit 1
				( update_local_cache_task ${relstring:1} ) &
			fi
		done
	fi

	cat <<EOF > $TMPDIR/update.json
{ "issue": {
  "status_id": $(status_to_id $status),
  "tracker_id": $(tracker_to_id $tracker),
  "subject": "${subject//\"/\\\"}"
}}
EOF

	if [ "$done_ratio" ] && [ "$done_ratio" != null ] ; then
		jq ".issue.done_ratio += $done_ratio" $TMPDIR/update.json > $TMPDIR/update.json2
		mv $TMPDIR/update.json2 $TMPDIR/update.json
	fi

	local newparent="$(find_new_parent $issueid)"
	if [ "$newparent" ] ; then
		jq ".issue.parent_issue_id += \"$newparent\"" $TMPDIR/update.json > $TMPDIR/update.json2
		mv $TMPDIR/update.json2 $TMPDIR/update.json
	fi

	local newproject="$(find_new_project $issueid)"
	if [ "$newproject" ] ; then
		jq ".issue.project_id += ${newproject##PJ}" $TMPDIR/update.json > $TMPDIR/update.json2
		mv $TMPDIR/update.json2 $TMPDIR/update.json
	fi

	# cat $TMPDIR/update.json
	# TODO: イテレートしたら、誤った issue に関連を与えてしまわないだろうか。
	__upload_ticket $TMPDIR/update.json $issueid || return 1
	if [ -s "$TMPDIR/upload_relations.json" ] ; then
		echo "update relations"
	fi

	( update_local_cache_task $issueid ) &
}

# 追加行は ID がまだ決まっていないので、識別のために N で始まる仮の ID を用いる。
# TODO: 新規チケットに関連をもたせることができない
create_pjtree_ticket() {
	local issueid="$1"
	local line="$2"

	local metafield="$(echo "$line" | awk -F'[><]' '{print $2}')"
	local tracker="$(echo $metafield | cut -f1 -d\|)"
	local status="$(echo $metafield | cut -f2 -d\|)"
	# local newrelations="$(echo "$line" | sed 's/.*(\([0-9>|=#,-]\+\)).*/\1/')"
	local subject="$(echo "$line" | cut -f2- -d \> | sed 's/^ *//')"

	# TODO: remove duplicate
	cat <<EOF > $TMPDIR/update.json
{ "issue": {
  "status_id": $(status_to_id $status),
  "tracker_id": $(tracker_to_id $tracker),
  "subject": "${subject//\"/\\\"}"
}}
EOF

	local newparent="$(find_new_parent $issueid)"
	# echo "--> $issueid $newparent"
	if [ "$newparent" ] ; then
		jq ".issue.parent_issue_id += \"$newparent\"" $TMPDIR/update.json > $TMPDIR/update.json2
		mv $TMPDIR/update.json2 $TMPDIR/update.json
	fi

	local newproject="$(find_new_project $issueid)"
	# echo "--> $issueid $newproject"
	if [ "$newproject" ] ; then
		jq ".issue.project_id += ${newproject##PJ}" $TMPDIR/update.json > $TMPDIR/update.json2
		mv $TMPDIR/update.json2 $TMPDIR/update.json
	fi

	# TODO: handle relation
	mkdir -p $TMPDIR/$issueid
	__create_ticket $TMPDIR/update.json $issueid > $TMPDIR/$issueid/create.result.json
	local newissueid=$(jq -r ".issue.id" $TMPDIR/$issueid/create.result.json)
	[ "$newissueid" == null ] && echo "failed to get new ticket ID" && return 1
	sed -i -e "s/ $issueid/ $newissueid/" -e "s/+$issueid /+$newissueid /" $TMPDIR/pjtree.diff

	echo "created new ticket $newissueid"
	mkdir -p $RM_CONFIG/edit_memo/$newissueid
	if [ -s "$TMPDIR/upload_relations.json" ] ; then
		echo "update relations"
		# TODO
	fi

	( update_local_cache_task $newissueid ) &
}

remove_pjtree_ticket() {
	local id="$1"

	remove_ticket $id || exit 1
	rmeove_ticket_from_local_cache $id
}

get_list_of_changed_tickets() {
	local file="$1"

	grep "^[+-] " "$file" | awk '{print $2}' | sort | uniq
}

replace_new_ticket_line_with_number_id() {
	local draft="$1"

	gawk -i inplace '{
		if ($0 ~ /^ *new /) {
			print gensub(/new/, "N"NR, 1, $0)
		} else {
			print $0
		}
	}' $draft || exit 1
}

show_ticket_journal() {
	local tid=$1
	local tidtmp="$TMPDIR/$tid"

	mkdir -p $tidtmp
	fetch_issue $tid "" $tidtmp/issue_journal.json

	jq -r ".journals[].id" $tidtmp/issue_journal.json | tac > $tidtmp/journal_ids
	for jid in $(cat $tidtmp/journal_ids) ; do
		jq -r ".journals[] | select(.id == $jid) | .details[] | select(.name == \"description\") | .old_value" $tidtmp/issue_journal.json > $tidtmp/journal_${jid}.1
		jq -r ".journals[] | select(.id == $jid) | .details[] | select(.name == \"description\") | .new_value" $tidtmp/issue_journal.json > $tidtmp/journal_${jid}.2
		journal_note=$(jq -r ".journals[] | select(.id == $jid) | .notes" $tidtmp/issue_journal.json)

		if [ ! -s "$tidtmp/journal_${jid}.1" ] && [ ! "$journal_note" ] ; then
			continue
		fi

		# TODO: ステータスの変更を表示させる
		printf "${CL_YELLOW}journal ID: ${jid}${CL_NC}\n" >> $tidtmp/abcd
		journal_date=$(jq -r ".journals[] | select(.id == $jid) | .created_on" $tidtmp/issue_journal.json)
		user_name=$(jq -r ".journals[] | select(.id == $jid) | .user.name" $tidtmp/issue_journal.json)
		echo "Author: $user_name" >> $tidtmp/abcd
		echo "Date: $(date -d $journal_date)" >> $tidtmp/abcd

		echo "" >> $tidtmp/abcd

		if [ "$journal_note" ] ; then
			echo "$journal_note" | sed 's/^/    /' >> $tidtmp/abcd
			echo "" >> $tidtmp/abcd
		fi
		git -c core.whitespace=cr-at-eol diff --color $tidtmp/journal_${jid}.1 $tidtmp/journal_${jid}.2 | tail +5 >> $tidtmp/abcd
	done
}

show_ticket_tree() {
	local tid=$1
	local indent=$2
	local tidtmp="$TMPDIR/$tid"

	mkdir -p $tidtmp
	fetch_issue $tid "" $tidtmp/issue_journal.json

	local abc=$(eval printf "%.0s#" {1..${indent}})
	jq -r ".subject" $tidtmp/issue_journal.json | sed "s/^/${abc} /"
	jq -r ".description" $tidtmp/issue_journal.json | sed "s/\r//g" | sed "s/^\(#\+ \)/${abc}\1/" > $tidtmp/desc
	if [ "$(cat $tidtmp/desc)" != "null" ] ; then
		cat $tidtmp/desc
	fi
}
