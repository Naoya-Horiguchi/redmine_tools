# TODO: conflict check before upload
# DONE: 親子関係など、既存の設定のアンセット方法について。
#       -> #+Assigned: 行自体が存在しない -> 更新せず
#       -> #+Assigned: null とする -> unset

json_add_text() {
	local file="$1"
	local position="$2"
	local text="$3"

	cp $file $RM_CONFIG/tmp.json
	jq --arg text "$text" $position='$text' $RM_CONFIG/tmp.json > $file
}

json_add_int() {
	local file="$1"
	local position="$2"
	local int="$3"

	cp $file $RM_CONFIG/tmp.json
	jq $position=$int $RM_CONFIG/tmp.json > $file
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
	# TODO: 大文字小文字区別せず
	local status="$(grep -i ^#\+status: $file | sed 's|^#+status: *||i')"
	local status_id=$(jq -r ".issue_statuses[] | select(.name == \"$status\") | .id" $RM_CONFIG/issue_statuses.json)
	[ ! "$status_id" ] && status_id=$status
	local priority="$(grep -i ^#\+priority: $file | sed 's|^#+priority: *||i')"
	local priority_id=$(jq -r ".issue_priorities[] | select(.name == \"$priority\") | .id" $RM_CONFIG/priorities.json)
	[ ! "$priority_id" ] && priority_id=$priority
	local parent_id="$(grep -i ^#\+parentissue: $file | sed 's|^#+parentissue: *||i')"
	# TODO: user name/id どちらでも登録できるようにしたい
	# TODO: ユーザリストがない場合の対応
	if [ "$RM_USERLIST" ] ; then
		local assigned="$(grep -i ^#\+assigned: $file | sed 's|^#+assigned: *||i')"
		local assigned_id=$(jq -r ".users[] | select(.login == \"$assigned\") | .id" $RM_CONFIG/users.json)
		[ ! "$assigned_id" ] && assigned_id=$assigned
	fi
	local done_ratio="$(grep -i ^#\+doneratio: $file | sed 's|^#+doneratio: *||i')"
	local estimate="$(grep -i ^#\+estimate: $file | sed 's|^#+estimate: *||i')"
	local due_date="$(grep -i ^#\+duedate: $file | sed 's|^#+duedate: *||i')"
	# category
	local version="$(grep -i ^#\+version: $file | sed 's|^#+version: *||i')"
	# TODO: input in string format "<project> - <version>" is not supported yet.
	if [ -s "$RM_CONFIG/versions/${project_id}.json" ] ; then
		local version_id=$(jq -r ".versions[] | select(.name == \"$status\") | .id" $RM_CONFIG/versions/${project_id}.json)
	fi
	[ ! "$version_id" ] && version_id=$version
	# blocks, follows など、関連に関わる要素
	grep -v "^#+" $file | awk '/^### NOTE ###/{p=1;next}{if(!p){print}}' > $TMPD/$issue/body
	grep -v "^#+" $file | awk '/^### NOTE ###/{p=1;next}{if(p){print}}' > $TMPD/$issue/note

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
	fi
	if [ "$due_date" ] ; then
		local date_text="$(date -d "$due_date" +%Y-%m-%d)"
		json_add_text $TMPD/$issue/upload.json .issue.due_date "$date_text" || return 1
	fi
	# category
	if [ "$version_id" ] ; then
		json_add_int $TMPD/$issue/upload.json .issue.fixed_version_id $version_id || return 1
	fi
	if [ -s "$TMPD/$issue/body" ] ; then
		json_add_text $TMPD/$issue/upload.json .issue.description "$(cat $TMPD/$issue/body)" || return 1
	fi
	if [ -s "$TMPD/$issue/note" ] ; then
		json_add_text $TMPD/$issue/upload.json .issue.notes "$(cat $TMPD/$issue/note)" || return 1
	fi
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

__curl_limit() {
	local api="$1"
	local out="$2"
	local data="$3"
	local limit="$4"
	local step=100

	local requestbase="$RM_BASEURL${api}?key=${RM_KEY}"
	local totalcount=$(curl ${INSECURE:+-k} -s "${requestbase}${data:+&$data}" | jq .total_count)
	[ ! "$totalcount" ] && return 1
	[ "$limit" -gt "$totalcount" ] && limit=$totalcount
	local pages=$[($limit - 1) / $step + 1]
	[ ! "$totalcount" ] && return 1

	local tmpd=$(mktemp -d)
	local files=
	for i in $(seq 0 $[pages-1]) ; do
		curl ${INSECURE:+-k} -s "${requestbase}&offset=$[i*step]&limit=$[limit-i*step]" > $tmpd/page.$i.json || exit 1
		files="$files $tmpd/page.$i.json"
	done

	jq 'reduce inputs as $i (.; .issues += $i.issues)' $files > $out
	rm -rf $tmpd
}

__curl() {
	local api="$1"
	local out="$2"
	local tmpf=$(mktemp)
	local data="$3"

	[ ! "$out" ] && echo "invalid input" && return 1
	curl ${INSECURE:+-k} -s "$RM_BASEURL${api}?key=$RM_KEY${data:+&$data}" > $tmpf || return 1
	if [ -s "$tmpf" ] ; then
		mkdir -p $(dirname $out)
		mv $tmpf $out
	else
		return 1
	fi
}

fetch_issue() {
	local issueid="$1"
	local relcsv="$2"
	local tmpjson="$3"
	local tmpf=$RM_CONFIG/tmp.tmp

	if [ "$relcsv" ] ; then
		__curl "/issues/$issueid/relations.json" /tmp/32 || return 1
		jq -r '.relations[] | [.issue_id, .relation_type, .issue_to_id, .id] | @csv' /tmp/32 | tr -d \" > $relcsv
	fi

	if [ "$tmpjson" ] ; then
		__curl "/issues/${issueid}.json" /tmp/37 "include=journals" || return 1
		jq -r .issue /tmp/37 > $tmpjson
	fi
}

__format_to_draft() {
	local tmpjson="$1"
	local tmpfile="$2"
	local relcsv="$3"

	# cat $tmpjson
	[ -s "$tmpfile" ] && rm $tmpfile
	echo "#+DoneRatio: $(jq -r .done_ratio $tmpjson)" >> $tmpfile
	echo "#+Status: $(jq -r .status.name $tmpjson)" >> $tmpfile
	echo "#+Subject: $(jq -r .subject $tmpjson)" >> $tmpfile
	# echo "#+Issue: $(jq -r .id $tmpjson)" >> $tmpfile
	echo "#+Project: $(jq -r .project.name $tmpjson)" >> $tmpfile
	echo "#+Tracker: $(jq -r .tracker.name $tmpjson)" >> $tmpfile
	echo "#+Priority: $(jq -r .priority.name $tmpjson)" >> $tmpfile
	echo "#+ParentIssue: $(jq -r .parent.name $tmpjson)" >> $tmpfile
	if [ "$RM_USERLIST" ] ; then
		echo "#+Assigned: $(jq -r .assigned_to.name $tmpjson)" >> $tmpfile
	fi
	echo "#+Estimate: $(jq -r .estimated_hours $tmpjson)" >> $tmpfile
	echo "#+DueDate: $(jq -r .due_date $tmpjson)" >> $tmpfile
	# echo "#+Category: $(jq -r .fixed_version.id $tmpjson)" >> $tmpfile
	echo "#+Version: $(jq -r .fixed_version.id $tmpjson)" >> $tmpfile
	echo "#+Format: $RM_FORMAT" >> $tmpfile
	if [ "$relcsv" ] && [ -s "$relcsv" ] ; then
		while read line ; do
			local type=$(echo $line | cut -f2 -d,)
			if [ "$type" == "blocks" ] ; then
				echo "#+Blocks: $(echo $line | cut -f3 -d,)" >> $tmpfile
			elif [ "$type" == "precedes" ] ; then
				echo "#+Precedes: $(echo $line | cut -f1 -d,)" >> $tmpfile
			elif [ "$type" == "relates" ] ; then
				local relates_to=$(echo $line | cut -f3 -d,)
				if [ "$relates_to" -ne "$(jq -r .id $tmpjson)" ] ; then
					echo "#+Relates: $(echo $line | cut -f3 -d,)" >> $tmpfile
				fi
			else
				echo "unsupported type $type" >&2
				exit 1
			fi
		done<$relcsv
	fi
	if [ "$(jq -r .description $tmpjson)" != null ] ; then
		jq -r .description $tmpjson | sed "s/\r//g" >> $tmpfile
	fi
}

download_issue() {
	local issueid=$1
	local tmpjson=$TMPD/$issueid/issue.json
	local tmpfile=$TMPD/$issueid/draft.md
	local relcsv=$TMPD/$issueid/relations.csv

	fetch_issue "$issueid" "$relcsv" "$tmpjson" || return 1
	__format_to_draft "$tmpjson" "$tmpfile" "$relcsv" || return 1
	echo "### NOTE ### LINES BELOW THIS LINE ARE CONSIDERRED AS NOTES" >> $tmpfile
	local projectid=$(jq -r .project.id $tmpjson)
	rm -f $TMPD/$issueid/legends
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
	# TODO: tracker/status/priority は設定に応じたデフォルト値を与えるべき
	echo "#+Tracker: Epic" >> $tmpfile
	echo "#+Status: New" >> $tmpfile
	echo "#+Priority: Normal" >> $tmpfile
	echo "#+ParentIssue: null" >> $tmpfile
	if [ "$RM_USERLIST" ] ; then
		echo "#+Assigned: null" >> $tmpfile
	fi
	echo "#+DoneRatio: 0" >> $tmpfile
	echo "#+Estimate: 1" >> $tmpfile
	echo "#+DueDate: null" >> $tmpfile
	# echo "#+Category: null" >> $tmpfile
	echo "#+Version: null" >> $tmpfile
	echo "#+Format: $RM_FORMAT" >> $tmpfile
	# TODO: 他の関連
	echo "#+Blocks: " >> $tmpfile
	echo "#+Precedes: " >> $tmpfile
	echo "#+Follows: " >> $tmpfile
	echo "#+Relates: " >> $tmpfile
	echo "" >> $tmpfile
	rm -f $TMPD/new/legends
	generate_legends >> $TMPD/new/legends
}

keep_original_draft() {
	local issueid=$1

	cp $TMPD/$issueid/draft.md $TMPD/$issueid/tmp.draft.md
}

edit_issue() {
	local issueid=$1

	while true ; do
		if [ "$RM_LEGEND" ] ; then
			$EDITOR $TMPD/$issueid/legends $TMPD/$issueid/draft.md
		else
			$EDITOR $TMPD/$issueid/draft.md
		fi
		diff -u $TMPD/$issueid/tmp.draft.md $TMPD/$issueid/draft.md > $TMPD/$issueid/edit.diff
		if [ ! "$NO_DOWNLOAD" ] && [ ! -s "$TMPD/$issueid/edit.diff" ] ; then
			echo "no diff, so no need to upload"
			return 1
		fi
		cat $TMPD/$issueid/edit.diff
		[ "$LOCALTICKET" ] && return 0 # new local ticket
		echo
		echo "Your really upload this change? (y: yes, n: no, e: edit again)"
		read input
		if [ "$input" == y ] || [ "$input" == Y ] ; then
			return 0
		elif [ "$input" == n ] || [ "$input" == N ] ; then
			return 1
		else
			true # edit again
		fi
	done
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
			curl ${INSECURE:+-k} -s -X POST -H "Content-Type: application/json" --data-binary "{\"relation\": {\"issue_to_id\": $newprecedes, \"relation_type\": \"precedes\"}}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/$issueid/relations.json
		fi
	done

	grep -i "^+#+follows:" $TMPD/$issueid/edit.diff | while read line ; do
		local newfollows="$(grep -i ^+#+follows: $TMPD/$issueid/edit.diff | sed 's|^+#+follows: *||i')"

		if [ "$newfollows" ] ; then
			curl ${INSECURE:+-k} -s -X POST -H "Content-Type: application/json" --data-binary "{\"relation\": {\"issue_to_id\": $newfollows, \"relation_type\": \"follows\"}}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/$issueid/relations.json
		fi
	done

	grep -i "^+#+relates:" $TMPD/$issueid/edit.diff | while read line ; do
		local newrelates="$(grep -i ^+#+relates: $TMPD/$issueid/edit.diff | sed 's|^+#+relates: *||i')"

		if [ "$newrelates" ] ; then
			curl ${INSECURE:+-k} -s -X POST -H "Content-Type: application/json" --data-binary "{\"relation\": {\"issue_to_id\": $newrelates, \"relation_type\": \"relates\"}}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/$issueid/relations.json
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

	grep -i "^-#+relates:" $TMPD/$issueid/edit.diff | while read line ; do
		local oldrelates="$(grep -i ^-#+relates: $TMPD/$issueid/edit.diff | sed 's|^-#+relates: *||i')"
		if [ "$oldrelates" -gt "$issueid" ] ; then
			local relid=$(grep $issueid,relates,$oldrelates $relcsv | cut -f4 -d,)
		else
			local relid=$(grep $oldrelates,relates,$issueid $relcsv | cut -f4 -d,)
		fi

		if [ "$relid" ] ; then
			curl ${INSECURE:+-k} -s -X DELETE -H "Content-Type: application/json" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/relations/${relid}.json
		fi
	done
}

upload_issue() {
	local issueid=$1
	local tmpfile=$TMPD/$issueid/draft.md

	[ "$VERBOSE" ] && echo "upload_ticket"
	upload_ticket $tmpfile $issueid || return 1
	[ "$VERBOSE" ] && echo "update_relations $issueid"
	update_relations $issueid || return 1
}

create_issue() {
	local issueid=$1
	local tmpfile=$TMPD/$issueid/draft.md

	mkdir -p $TMPD/$issueid
	[ "$VERBOSE" ] && echo "create_ticket"
	create_ticket $tmpfile $issueid || return 1
	[ "$VERBOSE" ] && echo update_relations $issueid
	update_relations $issueid || return 1
}

prepare_draft_file() {
	local issueid=$1

	CLOCK_START=$(date --iso-8601=seconds)
	if [ "$LOCALTICKET" ] ; then
		if [ ! -s "$TMPD/$issueid/draft.md" ] ; then
			generate_issue_template || return 1
			mv $TMPD/new/* $TMPD/$issueid/
		fi
	elif [ "$issueid" == new ] ; then
		if [ ! "$NO_DOWNLOAD" ] ; then
			generate_issue_template || return 1
		fi
	elif [[ "$issueid" =~ ^L ]] ; then
		if [ ! -d "$TMPD/$issueid" ] ; then
			echo "local ticket $issueid not found"
			return 1
		fi
	else
		if [ ! "$NO_DOWNLOAD" ] ; then
			echo "Downloading ..."
			download_issue $issueid || return 1
		fi
	fi
	echo $CLOCK_START > $TMPD/$issueid/tmp.timestamp
	keep_original_draft $issueid
}

__check_opened() {
	local issueid=$1

	if [ ! -s "$TMPD/$issueid/.clock.log" ] ; then
		# echo "first open"
		return 0
	fi

	local tailsize=$(tail -n1 $TMPD/$issueid/.clock.log | wc -c)
	if [ "$tailsize" -eq 26 ] ; then # dangling open
		echo "Issue $issueid is opened by other process."
		return 1
	elif [ "$tailsize" -eq 52 ] ; then
		return 0
	else
		echo "clock log of issue $issueid is broken."
		return 1
	fi
}

update_issue() {
	local issueid=$1

	__check_opened $issueid || return 1

	echo -n "$CLOCK_START " >> $TMPD/$issueid/.clock.log
	while true ; do
		edit_issue $issueid || break
		[[ "$issueid" =~ ^L ]] && break
		local tstamp_saved="$(date -d $(cat $TMPD/$issueid/tmp.timestamp) +%s)"
		local tstamp_tmp=$(curl ${INSECURE:+-k} -s "$RM_BASEURL/issues.json?issue_id=${issueid}&key=${RM_KEY}&status_id=*" | jq -r ".issues[].updated_on")
		tstamp_tmp="$(date -d $tstamp_tmp +%s)"

		if [[ "$tstamp_saved" > "$tstamp_tmp" ]] || [ "$FORCE_UPDATE" ] ; then
			if [ "$issueid" == new ] ; then
				create_issue $issueid > $TMPD/$issueid/issue.json
				if [ "$?" -eq 0 ] ; then
					local newid=$(jq -r .issue.id $TMPD/$issueid/issue.json)
					if [ ! "$newid" ] || [ "$newid" == null ] ; then
						echo $TMPD/$issueid/issue.json
						echo "create issue failed"
					else
						echo "renaming $TMPD/$issueid/ to $TMPD/$newid/"
						mv $TMPD/$issueid/ $TMPD/$newid/
						issueid=$newid
					fi
					break
				fi
			else
				upload_issue $issueid && break
			fi
			echo "create_issue failed, check draft.md and/or network connection."
			echo "type any key to open editor again."
			read input
		else
			echo "The ticket $issueid was updated on server-side after you downloaded it into local file."
			get_conflict $issueid "$(cat $TMPD/$issueid/tmp.timestamp)" > $RM_CONFIG/tmp.draft.conflict
			if [ -s "$RM_CONFIG/tmp.draft.conflict" ] ; then
				# TODO: assuming markdown now, need to support textile format?
				echo "### CONFLICT ### YOU NEED TO CONFLICET THE BELOW DIFF MANUALLY" >> $TMPD/$issueid/draft.md
				echo "~~~" >> $TMPD/$issueid/draft.md
				cat $RM_CONFIG/tmp.draft.conflict >> $TMPD/$issueid/draft.md
				echo "~~~" >> $TMPD/$issueid/draft.md
				echo "type any key to reopen editor again."
				read input
				date --iso-8601=seconds > $TMPD/$issueid/tmp.timestamp
			else
				echo "So there's a conflict, you need to resolve conflict and manually upload it with options FORCE_UPDATE=true and NO_DOWNLOAD=true."
				echo "BE CAREFUL!! if you forget to add -f option on next call, draft file will be downloaded again and your local change will be overwritten."
				break
			fi
		fi
	done
	echo "$(date --iso-8601=seconds)" >> $TMPD/$issueid/.clock.log
}

declare -A PJTABLE;
generate_project_table() {
	declare -n pjtable=$1
	local id=
	local pjname=

	local ifs="$IFS"
	IFS=$'\n'
	for line in $(jq -r ".projects[] | [.id, .name] | @tsv" $RM_CONFIG/projects.json) ; do
		id=$(echo $line | cut -f1)
		pjname=$(echo $line | cut -f2)
		pjtable["$id"]="$pjname"
	done
	IFS="$ifs"
}

project_name() {
	local projectid=$1

	jq -r ".projects[] | select(.id == $projectid) | .name" $RM_CONFIG/projects.json
}

open_with_browser() {
	local url="$1"

	if [ "$BROWSER" ]; then
		$BROWSER "$url"
	elif which xdg-open > /dev/null; then
		xdg-open "$url"
	elif which gnome-open > /dev/null; then
		gnome-open "$url"
	else
		echo "Could not detect the web browser to use. Manually copy the following URL:"
		echo $url
	fi
}

generate_local_ticket_id() {
	# Assuming that local ticket ID is format like "L3" or "L70"
	local id="$(ls -1 $RM_CONFIG/edit_memo | grep ^L | sort -t L -k2n | tail -n1 | cut -f2 -dL)"

	if [ "$id" ] ; then
		echo -n "L$[id + 1]"
	else
		echo "L1"
	fi
}

check_ticket_id_format() {
	local issueid=$1

	if [[ "$issueid" =~ ^[0-9]+$ ]] ; then
		return 0
	elif [[ "$issueid" =~ ^L[0-9]+$ ]] ; then
		return 0
	else
		return 1
	fi
}

get_local_ticket_list() {
	ls -1 $RM_CONFIG/edit_memo | grep ^L
}

get_conflict() {
	local issueid=$1
	local tstamp=$(date -d $2 +%s)
	local tmpjson=$TMPD/$issueid/issue.json
	local draftfile=$TMPD/$issueid/draft.md

	[ ! "$tstamp" ] && echo "failed to get tstamp" >&2 && return 1

	fetch_issue "$issueid" "" "$tmpjson" || return 1
	__format_to_draft "$tmpjson" /tmp/sdf.tmp "" || return 1
	awk '/^### NOTE ###/{p=1;next}{if(!p){print}}' $draftfile > /tmp/draft.md

	diff -u /tmp/draft.md /tmp/sdf.tmp
}

if [ ! "$RM_BASEURL" ] ; then
	echo you need setup RM_BASEURL/RM_KEY
	exit 1
fi
