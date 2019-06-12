# TODO: conflict check before upload
# TODO: 設定項目をクリアする方法 (relation は対応済み)
# TODO: 親子関係など、既存の設置絵のアンセット方法について。
#       -> #+Assigned: 行自体が存在しない -> 更新せず
#       -> #+Assigned: null とする -> unset

json_add_text() {
	local file="$1"
	local position="$2"
	local text="$3"

	cp $file $TMPD/tmp.json
	jq --arg text "$text" $position='$text' $TMPD/tmp.json > $file
}

json_add_int() {
	local file="$1"
	local position="$2"
	local int="$3"

	cp $file $TMPD/tmp.json
	jq $position=$int $TMPD/tmp.json > $file
}

__update_ticket() {
	local file=$1
	local issueid=$2
	local subject="$(grep -i ^#\+subject: $file | sed 's|^#+subject: *||i')"
	local issue="$(grep -i ^#\+issue: $file | sed 's|^#+issue: *||i')"
	[ ! "$issue" ] && issue=$issueid
	# project name/id のどちらを与えても project_id が得られる。
	local project="$(grep -i ^#\+project: $file | sed 's|^#+project: *||i')"
	local project_id=$(jq -r ".projects[] | select(.name == \"$project\") | .id" $RM_CONFIG/projects.json)
	[ ! "$project_id" ] && project_id=$project
	local tracker="$(grep -i ^#\+tracker: $file | sed 's|^#+tracker: *||i')"
	local tracker_id=$(jq -r ".trackers[] | select(.name == \"$tracker\") | .id" $RM_CONFIG/trackers.json)
	[ ! "$tracker_id" ] && tracker_id=$tracker
	local status="$(grep -i ^#\+status: $file | sed 's|^#+status: *||i')"
	local status_id=$(jq -r ".issue_statuses[] | select(.name == \"$status\") | .id" $RM_CONFIG/issue_statuses.json)
	[ ! "$status_id" ] && status_id=$status
	local priority="$(grep -i ^#\+priority: $file | sed 's|^#+priority: *||i')"
	local priority_id=$(jq -r ".issue_priorities[] | select(.name == \"$priority\") | .id" $RM_CONFIG/priorities.json)
	[ ! "$priority_id" ] && priority_id=$priority
	local parent_id="$(grep -i ^#\+parentissue: $file | sed 's|^#+parentissue: *||i')"
	# TODO: user name/id どちらでも登録できるようにしたい
	# local assigned="$(grep -i ^#\+assigned: $file | sed 's|^#+assigned: *||i')"
	# local assigned_id=$(jq -r ".users[] | select(.login == \"$assigned\") | .id" $RM_CONFIG/users.json)
	[ ! "$assigned_id" ] && assigned_id=$assigned
	local done_ratio="$(grep -i ^#\+doneratio: $file | sed 's|^#+doneratio: *||i')"
	local estimate="$(grep -i ^#\+estimate: $file | sed 's|^#+estimate: *||i')"
	# category
    # fixed_version_id
	# format
	# blocks, follows など、関連に関わる要素
	grep -v "^#+" $file | awk '/^### NOTE ###/{p=1;next}{if(!p){print}}' > $TMPD/$issue/body

    # is_private
    # category_id
    # watcher_user_ids
	echo "{\"issue\": {}}" > $TMPD/$issue/upload.json
	if [ "$subject" ] ; then
		json_add_text $TMPD/$issue/upload.json .issue.subject "$subject" || return 1
	fi
	if [ "$issue" != new ] && [ "$issue" -gt 0 ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.id $issue || return 1
	fi
	if [ "$project_id" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.project_id $project_id || return 1
	fi
	if [ "$tracker_id" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.tracker_id $tracker_id || return 1
	fi
	if [ "$status_id" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.status_id $status_id || return 1
	fi
	if [ "$priority_id" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.priority_id $priority_id || return 1
	fi
	if [ "$parent_id" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.parent_issue_id $parent_id || return 1
	fi
	if [ "$assigned_id" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.assigned_to_id $assigned_id || return 1
	fi
	if [ "$done_ratio" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.done_ratio $done_ratio || return 1
	fi
	if [ "$estimate" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.estimated_hours $estimate || return 1
		cat $TMPD/$issue/upload.json
	fi
	# category
	# version
	json_add_text $TMPD/$issue/upload.json .issue.description "$(cat $TMPD/$issue/body)" || return 1
}

create_ticket() {
	local file=$1
	local issueid=$2
	__update_ticket $file $issueid || return 1
	if [ "$VERBOSE" ] ; then
		echo "json to be uploaded"
		cat $TMPD/$issueid/upload.json
	fi
	curl ${INSECURE:+-k} -H "Content-Type: application/json" -X POST --data-binary "@$TMPD/$issueid/upload.json" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues.json
}

upload_ticket() {
	local file=$1
	local issueid=$2
	__update_ticket $file $issueid || return 1
	if [ "$VERBOSE" ] ; then
		echo "json to be uploaded"
		cat $TMPD/$issueid/upload.json
	fi
	curl ${INSECURE:+-k} -H "Content-Type: application/json" -X PUT --data-binary "@$TMPD/$issueid/upload.json" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/${issueid}.json
}

download_issue() {
	local issueid=$1
	local tmpjson=$TMPD/$issueid/issue.json
	local tmpfile=$TMPD/$issueid/draft.md
	local relcsv=$TMPD/$issueid/relations.csv

	curl ${INSECURE:+-k} -s "$RM_BASEURL/issues.json?issue_id=${issueid}&key=${RM_KEY}&status_id=*" | jq .issues[] > $tmpjson
	curl ${INSECURE:+-k} -s "$RM_BASEURL/issues/$issueid/relations.json?key=$RM_KEY"  | jq -r '.relations[] | [.issue_id, .relation_type, .issue_to_id, .id] | @csv' | tr -d \" >  $relcsv
	curl ${INSECURE:+-k} -s "$RM_BASEURL/issues.json?issue_id=${issueid}&key=${RM_KEY}&status_id=*"
	local projectid=$(jq -r .project.id $tmpjson)

	# cat $tmpjson
	echo "#+Subject: $(jq -r .subject $tmpjson)" > $tmpfile
	echo "#+Issue: $(jq -r .id $tmpjson)" >> $tmpfile
	echo "#+Project: $(jq -r .project.id $tmpjson)" >> $tmpfile
	echo "#+Tracker: $(jq -r .tracker.name $tmpjson)" >> $tmpfile
	echo "#+Status: $(jq -r .status.name $tmpjson)" >> $tmpfile
	echo "#+Priority: $(jq -r .priority.name $tmpjson)" >> $tmpfile
	echo "#+ParentIssue: $(jq -r .parent.id $tmpjson)" >> $tmpfile
	echo "#+Assigned: $(jq -r .assigned_to.name $tmpjson)" >> $tmpfile
	echo "#+DoneRatio: $(jq -r .done_ratio $tmpjson)" >> $tmpfile
	echo "#+Estimate: $(jq -r .estimated_hours $tmpjson)" >> $tmpfile
	# echo "#+Category: $(jq -r .fixed_version.id $tmpjson)" >> $tmpfile
	echo "#+Version: $(jq -r .fixed_version.id $tmpjson)" >> $tmpfile
	echo "#+Format: $RM_FORMAT" >> $tmpfile

	if [ -s "$relcsv" ] ; then
		while read line ; do
			local type=$(echo $line | cut -f2 -d,)
			if [ "$type" == "blocks" ] ; then
				echo "#+blocks: $(echo $line | cut -f3 -d,)" >> $tmpfile
			elif [ "$type" == "precedes" ] ; then
				echo "#+precedes: $(echo $line | cut -f1 -d,)" >> $tmpfile
			else
				echo "unsupported type $type" >&2
				exit 1
			fi
		done<$relcsv
	fi
	# TODO: support due_date
	if [ "$(jq -r .description $tmpjson)" != null ] ; then
		jq -r .description $tmpjson | sed "s/\r//g" >> $tmpfile
	fi

	generate_legends >> $TMPD/$issueid/legends
	generate_version_legends $projectid >> $TMPD/$issueid/legends
}

generate_legends() {
	echo "### NOTE ###"
	echo "# projects"
	jq -r ".projects[] | [.id, .name] | @csv" $RM_CONFIG/projects.json | sort -k1n
	echo ""
	echo "# trackers"
	jq -r ".trackers[] | [.id, .name] | @csv" $RM_CONFIG/trackers.json | sort -k1n
	echo ""
	echo "# statuses"
	jq -r ".issue_statuses[] | [.id, .name] | @csv" $RM_CONFIG/issue_statuses.json | sort -k1n
	echo ""
	echo "# priorities"
	jq -r ".issue_priorities[] | [.id, .name] | @csv" $RM_CONFIG/priorities.json | sort -k1n
}

generate_version_legends() {
	local project=$1

	echo ""
	echo "# versions for project $project:"
	jq -r ".versions[] | [.id, .project.name, .name] | @csv" $RM_CONFIG/versions/$project.json | sort -k1n
}

generate_issue_template() {
	local tmpfile=$TMPD/new/draft.md
	local relcsv=$TMPD/new/relations.csv

	mkdir -p $TMPD/new

	echo "#+Subject: subject" > $tmpfile
	# echo "#+Issue: $(jq -r .id $tmpjson)" >> $tmpfile
	echo "#+Project: " >> $tmpfile
	echo "#+Tracker: Epic" >> $tmpfile
	echo "#+Status: New" >> $tmpfile
	echo "#+Priority: Normal" >> $tmpfile
	echo "#+ParentIssue: null" >> $tmpfile
	echo "#+Assigned: null" >> $tmpfile
	echo "#+DoneRatio: 0" >> $tmpfile
	echo "#+Estimate: 1" >> $tmpfile
	# echo "#+Category: null" >> $tmpfile
	echo "#+Version: null" >> $tmpfile
	echo "#+Format: $RM_FORMAT" >> $tmpfile
	# TODO: 他の関連
	echo "#+Blocks: " >> $tmpfile
	echo "#+Precedes: " >> $tmpfile
	echo "#+Follows: " >> $tmpfile
	echo "" >> $tmpfile
	generate_legends >> $TMPD/new/legends
}

edit_issue() {
	local issueid=$1
	local tmpfile=$TMPD/$issueid/draft.md

	cp $tmpfile $tmpfile.bak
	if [ "$RM_LEGEND" ] ; then
		$EDITOR $TMPD/$issueid/legends $tmpfile
	else
		$EDITOR $tmpfile
	fi
	diff -u $tmpfile.bak $tmpfile > $TMPD/$issueid/edit.diff
	if [ ! "$NO_DOWNLOAD" ] && [ ! -s "$TMPD/$issueid/edit.diff" ] ; then
		echo "no diff, so no need to upload"
		return 1
	fi
	# diff の具合によってはキャンセルする機会を与えるべきか?
	less $TMPD/$issueid/edit.diff
}

update_relations() {
	local issueid=$1
	local relcsv=$TMPD/$issueid/relations.csv

	grep -i "^+#+blocks:" $TMPD/$issueid/edit.diff | while read line ; do
		local newblocks="$(grep -i ^+#+blocks: $TMPD/$issueid/edit.diff | sed 's|^+#+blocks: *||i')"

		if [ "$newblocks" ] ; then
			curl ${INSECURE:+-k} -s -X POST -H "Content-Type: application/json" --data-binary "{\"relation\": {\"issue_to_id\": $newblocks, \"relation_type\": \"blocks\"}}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/$issueid/relations.json
		fi
	done

	grep -i "^+#+precedes:" $TMPD/$issueid/edit.diff | while read line ; do
		local newprecedes="$(grep -i ^+#+precedes: $TMPD/$issueid/edit.diff | sed 's|^+#+precedes: *||i')"

		if [ "$newprecedes" ] ; then
			curl ${INSECURE:+-k} -s -X POST -H "Content-Type: application/json" --data-binary "{\"relation\": {\"issue_id\": $newblocks, \"relation_type\": \"precedes\"}}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/$issueid/relations.json
		fi
	done

	grep -i "^+#+follows:" $TMPD/$issueid/edit.diff | while read line ; do
		local newfollows="$(grep -i ^+#+follows: $TMPD/$issueid/edit.diff | sed 's|^+#+follows: *||i')"

		if [ "$newfollows" ] ; then
			curl ${INSECURE:+-k} -s -X POST -H "Content-Type: application/json" --data-binary "{\"relation\": {\"issue_to_id\": $newfollows, \"relation_type\": \"follows\"}}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/$issueid/relations.json
		fi
	done

	grep -i "^-#+blocks:" $TMPD/$issueid/edit.diff | while read line ; do
		local oldblocks="$(grep -i ^-#+blocks: $TMPD/$issueid/edit.diff | sed 's|^-#+blocks: *||i')"
		local relid=$(grep $issueid,blocks,$oldblocks $relcsv | cut -f4 -d,)

		if [ "$relid" ] ; then
			curl ${INSECURE:+-k} -s -X DELETE -H "Content-Type: application/json" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/relations/${relid}.json
		fi
	done

	grep -i "^-#+precedes:" $TMPD/$issueid/edit.diff | while read line ; do
		local oldprecedes="$(grep -i ^-#+precedes: $TMPD/$issueid/edit.diff | sed 's|^-#+precedes: *||i')"
		local relid=$(grep $oldprecedes,precedes,$issueid $relcsv | cut -f4 -d,)

		if [ "$relid" ] ; then
			curl ${INSECURE:+-k} -s -X DELETE -H "Content-Type: application/json" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/relations/${relid}.json
		fi
	done
}

upload_issue() {
	local issueid=$1
	local tmpfile=$TMPD/$issueid/draft.md

	[ "$VERBOSE" ] && echo "upload_ticket"
	upload_ticket $tmpfile $issueid
	[ "$VERBOSE" ] && echo "update_relations $issueid"
	update_relations $issueid
}

create_issue() {
	local issueid=$1
	local tmpfile=$TMPD/$issueid/draft.md

	mkdir -p $TMPD/$issueid
	create_ticket $tmpfile $issueid
	[ "$VERBOSE" ] && echo update_relations $issueid
}

if [ ! "$RM_BASEURL" ] ; then
	echo you need setup RM_BASEURL/RM_KEY
	exit 1
fi
