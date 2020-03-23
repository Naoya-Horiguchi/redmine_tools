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
	local file="$1"
	local issueid="$2"
	local outjson="$3"

	[ ! "$outjson" ] && outjson=$TMPD/$issue/upload.json

	local subject="$(grep -i ^#\+subject: $file | sed 's|^#+subject: *||i')"
	local issue="$(grep -i ^#\+issue: $file | sed 's|^#+issue: *||i')"
	[ ! "$issue" ] && issue=$issueid
	local project="$(grep -i ^#\+project: $file | sed 's|^#+project: *||i')"
	local project_id="$(pjspec_to_pjid "$project")"
	local tracker="$(grep -i ^#\+tracker: $file | sed 's|^#+tracker: *||i')"
	local tracker_id="$(trackerspec_to_trackerid "$tracker")"
	local category="$(grep -i ^#\+category: $file | sed 's|^#+category: *||i')"
	local category_id="$(categoryspec_to_categoryid "$category")"
	local status="$(grep -i ^#\+status: $file | sed 's|^#+status: *||i')"
	local status_id="$(statusspec_to_statusid "$status")"
	local priority="$(grep -i ^#\+priority: $file | sed 's|^#+priority: *||i')"
	local priority_id="$(priorityspec_to_priorityid "$priority")"
	local parent_id="$(grep -i ^#\+parentissue: $file | sed 's|^#+parentissue: *||i')"
	# TODO: user name/id どちらでも登録できるようにしたい
	# TODO: ユーザリストがない場合の対応

	if [ ! -s "$RM_CONFIG/users.json" ] ; then
		local assigned="$(grep -i ^#\+assigned: $file | sed 's|^#+assigned: *||i')"
		local assigned_id="$(userspec_to_userid "$assigned")"
	fi
	local done_ratio="$(grep -i ^#\+doneratio: $file | sed 's|^#+doneratio: *||i')"
	local estimate="$(grep -i ^#\+estimate: $file | sed 's|^#+estimate: *||i')"
	# local due_date="$(grep -i ^#\+duedate: $file | sed 's|^#+duedate: *||i')"
	# category
	# local version="$(grep -i ^#\+version: $file | sed 's|^#+version: *||i')"
	# TODO: input in string format "<project> - <version>" is not supported yet.
	# if [ -s "$RM_CONFIG/versions/${project_id}.json" ] ; then
	# 	local version_id=$(jq -r ".versions[] | select(.name == \"$status\") | .id" $RM_CONFIG/versions/${project_id}.json)
	# fi
	# [ ! "$version_id" ] && version_id=$version
	# blocks, follows など、関連に関わる要素
	grep -v "^#+" $file | awk '/^@@@ NOTE @@@/{p=1;next}{if(!p){print}}' > $TMPDIR/body
	grep -v "^#+" $file | awk '/^@@@ NOTE @@@/{p=1;next}{if(p){print}}' > $TMPDIR/note

    # is_private
    # category_id
    # watcher_user_ids
	echo "{\"issue\": {}}" > $outjson
	if [ "$subject" ] ; then
		json_add_text $outjson .issue.subject "$subject" || return 1
	fi
	# if [ "$issue" ] && [ "$issue" != new ] && [ "$issue" -gt 0 ] ; then
	# 	json_add_int $outjson .issue.id $issue || return 1
	# fi
	if [ "$project_id" ] ; then
		json_add_int $outjson .issue.project_id $project_id || return 1
	fi
	if [ "$tracker_id" ] ; then
		json_add_int $outjson .issue.tracker_id $tracker_id || return 1
	fi
	if [ "$category_id" ] ; then
		json_add_int $outjson .issue.category_id $category_id || return 1
	fi
	if [ "$status_id" ] ; then
		json_add_int $outjson .issue.status_id $status_id || return 1
	fi
	if [ "$priority_id" ] ; then
		json_add_int $outjson .issue.priority_id $priority_id || return 1
	fi
	if [ "$parent_id" ] ; then
		json_add_int $outjson .issue.parent_issue_id $parent_id || return 1
	fi
	if [ "$assigned_id" ] ; then
		json_add_int $outjson .issue.assigned_to_id $assigned_id || return 1
	fi
	if [ "$done_ratio" ] ; then
		json_add_int $outjson .issue.done_ratio $done_ratio || return 1
	fi
	if [ "$estimate" ] ; then
		json_add_int $outjson .issue.estimated_hours $estimate || return 1
	fi
	# (2019/10/25 08:22) TODO 修正まで触らない
	# if [ "$due_date" ] ; then # && [ "$due_date" != "null" ] ; then
	# 	local date_text="$(date -d "$due_date" +%Y-%m-%d)"
	# 	json_add_text $outjson .issue.due_date "$date_text" || return 1
	# fi
	# category
	# if [ "$version_id" ] ; then
	# 	json_add_int $outjson .issue.fixed_version_id $version_id || return 1
	# fi
	# TODO: check '"' is escaped properly
	if [ -e "$TMPDIR/body" ] ; then
		json_add_text $outjson .issue.description "$(cat $TMPDIR//body)" || return 1
	fi
	if [ -s "$TMPDIR/note" ] ; then
		json_add_text $outjson .issue.notes "$(cat $TMPDIR/note)" || return 1
	fi
}

__create_ticket() {
	local file=$1

	curl ${INSECURE:+-k} -s -H "Content-Type: application/json" -X POST --data-binary "@${file}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues.json
}

create_ticket() {
	local file=$1
	local issueid=$2
	local outjson=$3
	[ ! "$outjson" ] && outjson=$TMPD/$issueid/upload.json
	__update_ticket "$file" "$issueid" "$outjson" || return 1
	__create_ticket $outjson || return 1
}

__upload_ticket() {
	local file=$1
	local issueid=$2

	curl ${INSECURE:+-k} -s -H "Content-Type: application/json" -X PUT --data-binary "@${file}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/${issueid}.json
}

upload_ticket() {
	local file=$1
	local issueid=$2
	local outjson=$3
	[ ! "$outjson" ] && outjson=$TMPD/$issueid/upload.json
	__update_ticket $file $issueid $outjson || return 1
	__upload_ticket $outjson $issueid
}

remove_ticket() {
	local issueid="$1"
	local api="/issues/${issueid}.json"
	local requestbase="$RM_BASEURL${api}?key=${RM_KEY}"

	curl ${INSECURE:+-k} -s -X DELETE "${requestbase}"
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
		curl ${INSECURE:+-k} -s "${requestbase}${data:+&$data}&offset=$[i*step]&limit=$[limit-i*step]" > $tmpd/page.$i.json || exit 1
		files="$files $tmpd/page.$i.json"
	done

	jq 'reduce inputs as $i (.; .issues += $i.issues)' $files > $out
	rm -rf $tmpd
}

__curl() {
	local api="$1"
	local out="$2"
	local data="$3"
	local tmpf=$TMPDIR/.tmp.$FUNCNAME

	[ ! "$out" ] && echo "invalid input" && return 1
	[ "$VERBOSE" ] && echo "curl ${INSECURE:+-k} -s -o $tmpf \"$RM_BASEURL${api}?key=$RM_KEY${data:+&$data}\""
	curl ${INSECURE:+-k} -s -o $tmpf "$RM_BASEURL${api}?key=$RM_KEY${data:+&$data}" || return 1
	if [ -s "$tmpf" ] ; then
		mkdir -p $(dirname $out)
		cp $tmpf $out
	else
		return 1
	fi
}

fetch_issue() {
	local issueid="$1"
	local relcsv="$2"
	local tmpjson="$3"

	if [ "$relcsv" ] ; then
		__curl "/issues/$issueid/relations.json" /tmp/32 || return 1
		jq -r '.relations[] | [.issue_id, .relation_type, .issue_to_id, .id] | @csv' /tmp/32 | tr -d \" > $relcsv
	fi

	if [ "$tmpjson" ] ; then
		__curl "/issues/${issueid}.json" $TMPDIR/tmp.37 "include=journals" || return 1
		jq -r .issue $TMPDIR/tmp.37 > $tmpjson
	fi
}

__format_to_draft() {
	local tmpjson="$1"
	local tmpfile="$2"
	local relcsv="$3"

	# cat $tmpjson
	[ -s "$tmpfile" ] && echo -n "" > $tmpfile
	echo "#+DoneRatio: $(jq -r .done_ratio $tmpjson)" >> $tmpfile
	echo "#+Status: $(jq -r .status.name $tmpjson)" >> $tmpfile
	echo "#+Subject: $(jq -r .subject $tmpjson)" >> $tmpfile
	# echo "#+Issue: $(jq -r .id $tmpjson)" >> $tmpfile
	echo "#+Project: $(jq -r .project.name $tmpjson)" >> $tmpfile
	echo "#+Tracker: $(jq -r .tracker.name $tmpjson)" >> $tmpfile
	echo "#+Category: $(jq -r .category.name $tmpjson)" >> $tmpfile
	echo "#+Priority: $(jq -r .priority.name $tmpjson)" >> $tmpfile
	echo "#+ParentIssue: $(jq -r .parent.id $tmpjson)" >> $tmpfile
	if [ "$RM_USERLIST" ] ; then
		echo "#+Assigned: $(jq -r .assigned_to.name $tmpjson)" >> $tmpfile
	fi
	echo "#+Estimate: $(jq -r .estimated_hours $tmpjson)" >> $tmpfile
	# (2019/10/25 08:21) TODO なんか壊れているので修正されるまで触らないことにする。
	# echo "#+DueDate: $(jq -r .due_date $tmpjson)" >> $tmpfile
	# echo "#+Version: $(jq -r .fixed_version.id $tmpjson)" >> $tmpfile
	# echo "#+Format: $RM_FORMAT" >> $tmpfile
	if [ "$(jq -r .description $tmpjson)" != null ] ; then
		jq -r .description $tmpjson | sed "s/\r//g" >> $tmpfile
	fi
}

update_relations2() {
	local issueid="$1"
	local draft="$2"

	generate_relation_json_from_draft $issueid $draft | while read line ; do
		echo "$line" > $TMPDIR/relation.json
		create_relation $issueid $TMPDIR/relation.json || exit 1
	done
}

check_issue_exist() {
	local issueid="$1"

	jq ".issues[] | select(.id == $issueid)" $RM_CONFIG/issues.json > $TMPDIR/issue.exist
	test -s $TMPDIR/issue.exist
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
		echo "Please edit $TMPD/$issueid/.clock.log and resolved unclosed clock"
		return 1
	elif [ "$tailsize" -eq 51 ] || [ "$tailsize" -eq 52 ] ; then
		return 0
	else
		echo "clock log of issue $issueid is broken."
		return 1
	fi
}

__open_clock() {
	local issueid=$1
	mkdir -p $TMPD/$issueid
	echo -n "$(date --iso-8601=seconds) " >> $TMPD/$issueid/.clock.log
	perl -pi -e 'chomp if eof' "$TMPD/$issueid/.clock.log"
}

__close_clock() {
	local issueid=$1
	trap 2
	perl -pi -e 'chomp if eof' "$TMPD/$issueid/.clock.log"
	echo "$(date --iso-8601=seconds)" >> $TMPD/$issueid/.clock.log

	local record="$(tail -n1 $TMPD/$issueid/.clock.log)"
	local cin=$(echo $record | cut -f1 -d' ')
	local cout=$(echo $record | cut -f2 -d' ')
	local tin=$(date -d $cin +%s 2> /dev/null)
	local tout=$(date -d $cout +%s 2> /dev/null)
	local clock=$[$tout - $tin]

	# TODO: error handling, activity?
	if [ "$RM_TIME_ENTRY" == true ] ; then
		if [ "$clock" -ge "${RM_TIME_ENTRY_MIN:=120}" ] ; then
			if [ "$clock" -le "${RM_TIME_ENTRY_MAX:=14400}" ] ; then
				create_time_entry "$issueid" "$(calc_clock_hour $clock)" "" "" "" > /dev/null
			fi
		fi
	fi
}

calc_clock_hour() {
	local clock="$1"
	# round down to min
	local time="$(echo "scale=2 ; $clock / 3600" | bc 2> /dev/null)"

	# local min="$[($clock / 60) % 60]"
	# local hour="$[$clock / 60 / 60]"
	# printf "%d:%02d\n" $hour $min

	echo $time
}

create_time_entry() {
	local issueid="$1"
	local clockstr="$2"
	local spenton="$3"
	local activity="$4"
	local comment="$5"
	local outjson=$TMPD/$issueid/create_time_entry.json

	echo "{\"time_entry\": {}}" > $outjson
	json_add_int $outjson .time_entry.issue_id "$issueid" || return 1
	json_add_int $outjson .time_entry.hours "$clockstr" || return 1

	if [ "$spenton" ] ; then
		json_add_text $outjson .issue.spent_on "$spenton" || return 1
	fi
	if [ "$activity" ] ; then
		json_add_int $outjson .time_entry.activity_id "$activity" || return 1
	fi
	if [ "$comment" ] ; then
		json_add_text $outjson .issue.comments "$comment" || return 1
	fi

	curl ${INSECURE:+-k} -s -H "Content-Type: application/json" -X POST --data-binary "@${outjson}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/time_entries.json
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

RM_LAST_DOWNLOAD=$RM_CONFIG/tmp.last_download

update_local_cache() {
	local data="${ASSIGNED_OPT}&status_id=*&include=relations&sort=updated_on:desc"

	if [ -s "$RM_LAST_DOWNLOAD" ] ; then
		__curl_limit "/issues.json" $RM_CONFIG/tmp.issues.json "$data&updated_on=>=$(cat $RM_LAST_DOWNLOAD)" 10000 || return 1
		jq -r ".issues[]" $RM_CONFIG/tmp.issues.json > $RM_CONFIG/tmp.new_items
		total_count="$(jq -r '.total_count' $RM_CONFIG/tmp.issues.json)"
		if [ "$total_count" -gt 0 ] ; then
			jq -r --slurpfile new_items $RM_CONFIG/tmp.new_items \
			   '.issues |= [ . + $new_items | group_by(.id)[] | add ]' $RM_CONFIG/issues.json > $RM_CONFIG/issues.json.tmp || return 1
			mv $RM_CONFIG/issues.json.tmp $RM_CONFIG/issues.json
		else
			echo "local cache is up-to-date" >&2
		fi
	else
		__curl_limit "/issues.json" $RM_CONFIG/issues.json "$data" 10000 || return 1
	fi
	date --utc +"%Y-%m-%dT%H:%M:%SZ" > $RM_LAST_DOWNLOAD
}

# WIP
# TODO: ticket remove
# TODO: relations are not updated automatically
# TODO: download server data in background
# TODO: update locking
update_local_cache_task() {
	local id="$1"

	__curl "/issues.json" $TMPDIR/tmp.update_local_cache_task "&issue_id=$id&include=relations&status_id=*"
	jq -r ".issues[]" $TMPDIR/tmp.update_local_cache_task > $TMPDIR/tmp.update_local_cache_task_new
	jq -r --slurpfile new_items $TMPDIR/tmp.update_local_cache_task_new \
	   '.issues |= [ . + $new_items | group_by(.id)[] | add ]' $RM_CONFIG/issues.json > $TMPDIR/tmp.issues.json || return 1
	mv $TMPDIR/tmp.issues.json $RM_CONFIG/issues.json
}

rmeove_ticket_from_local_cache() {
	local id="$1"

	# saving local cache into saved directory
	jq -r ".issues[] | select(.id == $ISSUEID)" $RM_CONFIG/issues.json > $TMPD/$ISSUEID/issue.deleted.json
	jq "del(.issues[] | select(.id == $id))" $RM_CONFIG/issues.json > $TMPDIR/tmp.issues.json
	if [ "$(wc -c $RM_CONFIG/issues.json | cut -f1 -d' ')" -eq "$(wc -c $TMPDIR/tmp.issues.json | cut -f1 -d' ')" ] ; then
		# not found
		return 1
	else
		mv $TMPDIR/tmp.issues.json $RM_CONFIG/issues.json
		return 0
	fi
}

RM_LAST_DOWNLOAD_TE=$RM_CONFIG/tmp.last_download_time_entry

update_local_cache_time_entries() {
	local data="${ASSIGNED_OPT}&status_id=*&include=relations&sort=updated_on:desc"

	if [ -s "$RM_LAST_DOWNLOAD_TE" ] ; then
		__curl_limit "/time_entries.json" $RM_CONFIG/tmp.time_entries.json "$data&from=$(cat $RM_LAST_DOWNLOAD_TE)" 10000 || return 1
		jq -r ".time_entries[]" $RM_CONFIG/tmp.time_entries.json > $RM_CONFIG/tmp.new_time_entries
		total_count="$(jq -r '.total_count' $RM_CONFIG/tmp.time_entries.json)"
		if [ "$total_count" -gt 0 ] ; then
			jq -r --slurpfile new_time_entries $RM_CONFIG/tmp.new_time_entries \
			   '.time_entries |= [ . + $new_time_entries | group_by(.id)[] | add ]' $RM_CONFIG/time_entries.json > $RM_CONFIG/time_entries.json.tmp || return 1
			mv $RM_CONFIG/time_entries.json.tmp $RM_CONFIG/time_entries.json
		else
			echo "local cache is up-to-date" >&2
		fi
	else
		__curl_limit "/time_entries.json" $RM_CONFIG/time_entries.json "$data" 10000 || return 1
	fi
	date --utc +"%Y-%m-%dT%H:%M:%SZ" > $RM_LAST_DOWNLOAD_TE
}

declare -A SUBTASK_TABLE
declare -A TRACKER_TABLE
declare -A STATUS_TABLE
declare -A SUBJECT_TABLE
get_subtask_table() {
	local data=$1

	echo -n "" > $TMPDIR/top_level_tasks
	local ifs="$IFS"
	IFS=$'\n'
	for line in $(jq -r ". | [.project.id, .id, .parent.id, .tracker.name, .status.name, .subject] | @tsv" $data | sort -k2n) ; do
		local taskid=$(echo $line | cut -f2)
		local parentid=$(echo $line | cut -f3)
		if [ "$parentid" ] ; then
			SUBTASK_TABLE[$parentid]="${SUBTASK_TABLE[$parentid]} $taskid"
		else
			echo $taskid >> $TMPDIR/top_level_tasks
		fi
		TRACKER_TABLE[$taskid]="$(echo $line | cut -f4)"
		STATUS_TABLE[$taskid]="$(echo $line | cut -f5)"
		SUBJECT_TABLE[$taskid]="$(echo $line | cut -f6)"
	done
	IFS="$ifs"
}

get_metadata_table() {
	local data="$1"

	local ifs="$IFS"
	IFS=$'\n'
	for line in $(jq -r ".issues[] | [.id, .tracker.name, .status.name, .subject] | @tsv" $data | sort -k1n) ; do
		local taskid="$(echo $line | cut -f1)"
		TRACKER_TABLE[$taskid]="$(echo $line | cut -f2)"
		STATUS_TABLE[$taskid]="$(echo $line | cut -f3)"
		SUBJECT_TABLE[$taskid]="$(echo $line | cut -f4)"
	done
	IFS="$ifs"
}

declare -A RELATION_TABLE
get_relation_table() {
	local data=$1

	local ifs="$IFS"
	IFS=$'\n'
	for line in $(jq -r ".relations[] | [.id, .issue_id, .issue_to_id, .relation_type] | @tsv" $data | sort -k1n | uniq) ; do
		local issueid=$(echo $line | cut -f2)
		local issuetoid=$(echo $line | cut -f3)
		local reltype=$(echo $line | cut -f4)
		local relstr="$(get_relation_string $issuetoid $reltype)"

		if [ "${RELATION_TABLE[$issueid]}" ] ; then
			RELATION_TABLE[$issueid]="${RELATION_TABLE[$issueid]},$relstr"
		else
			RELATION_TABLE[$issueid]="$relstr"
		fi
	done
	IFS="$ifs"
}

tracker_colored() {
	local stat
	printf "${CL_GREEN}${TRACKER_TABLE[$taskid]}${CL_NC}"
}

get_tracker_part() {
	local taskid=$1

	if [ "${STATUS_TABLE[$taskid]}" ] ; then
		printf "${CL_GREEN}${TRACKER_TABLE[$taskid]}${CL_NC}"
	else
		echo "-"
	fi
}

get_status_part() {
	local taskid=$1

	if [ "${STATUS_TABLE[$taskid]}" ] ; then
		if status_closed "${STATUS_TABLE[$taskid]}" ; then
			printf "${CL_DGRAY}${STATUS_TABLE[$taskid]}${CL_NC}"
		else
			printf "${CL_YELLOW}${STATUS_TABLE[$taskid]}${CL_NC}"
		fi
	else
		echo "-"
	fi
}

get_relation_part() {
	local taskid=$1

	if [ "${RELATION_TABLE[$taskid]}" ] ; then
		printf "(${CL_RED}${RELATION_TABLE[$taskid]}${CL_NC}) "
	fi
}

get_meta_part() {
	# printf "<${CL_GREEN}${TRACKER_TABLE[$taskid]}|${STATUS_TABLE[$taskid]}${CL_NC}> "
	printf "<$(get_tracker_part "$1")|$(get_status_part "$1")> "
}

edit_local_ticket() {
	local issueid="$1"
	local draft=$TMPD/$issueid/$RM_DRAFT_FILENAME

	echo -n "$(date --iso-8601=seconds) " >> $TMPD/$issueid/.clock.log
	trap "date --iso-8601=seconds >> $TMPDIR/$issueid/.clock.log ; exit 0" 2
	pushd $TMPD/$issueid
	$EDITOR $draft
	popd
	trap 2
	echo "$(date --iso-8601=seconds)" >> $TMPD/$issueid/.clock.log
}

download_target_issue() {
	__curl "/issues.json" $TMPDIR/tmp.before_edit "&issue_id=$issueid&include=relations"
}

convert_to_draft_from_json() {
	local issueid="$1"
	local jsonfile="$2"
	local tmpjson=$TMPDIR/tmp.json
	local draft="$3"

	# jq -r ".issues[] | select(.id == $issueid)" $RM_CONFIG/issues.json > $tmpjson
	jq -r ".issues[] | select(.id == $issueid)" $jsonfile > $tmpjson

	[ -s "$draft" ] && echo -n "" > $draft
	echo "#+DoneRatio: "$(jq -r .done_ratio $tmpjson) >> $draft
	echo "#+Status: $(jq -r '.status.name' $tmpjson)" >> $draft
	echo "#+Subject: $(jq -r .subject $tmpjson)" >> $draft
	echo "#+Project: $(jq -r .project.name $tmpjson)" >> $draft
	echo "#+Tracker: $(jq -r .tracker.name $tmpjson)" >> $draft
	echo "#+Category: $(jq -r .category.name $tmpjson)" >> $draft
	echo "#+Priority: $(jq -r .priority.name $tmpjson)" >> $draft
	echo "#+ParentIssue: $(jq -r .parent.id $tmpjson)" >> $draft
	if [ "$RM_USERLIST" ] ; then
		echo "#+Assigned: $(jq -r .assigned_to.name $tmpjson)" >> $draft
	fi
	echo "#+Estimate: $(jq -r .estimated_hours $tmpjson)" >> $draft
	# echo "#+DueDate: $(jq -r .due_date $tmpjson)" >> $draft
	# echo "#+Category: $(jq -r .fixed_version.id $tmpjson)" >> $draft
	# echo "#+Version: $(jq -r .fixed_version.id $tmpjson)" >> $draft
	# echo "#+Format: $RM_FORMAT" >> $draft

	local ifs="$IFS"
	IFS=$'\n'
	for line in $(jq -r ".issues[] | select(.id == $issueid) | .relations[] | [.relation_type, .issue_to_id] | @tsv" $RM_CONFIG/issues.json) ; do
		local reltype=$(echo $line | cut -f1)
		# TODO: upper case first character
		# foo="$(tr '[:lower:]' '[:upper:]' <<< ${reltype:0:1})${reltype:1}"
		local issuetoid=$(echo $line | cut -f2)
		echo "#+${reltype}: ${issuetoid}" >> $draft
	done
	IFS="$ifs"

	if [ "$(jq -r .description $tmpjson)" != null ] ; then
		jq -r .description $tmpjson | sed "s/\r//g" >> $draft
	fi
}

ask_done_ratio_update3() {
	local done_ratio="$(grep -i ^#\+doneratio: ${draft}.before_edit | sed 's|^#+doneratio: *||i')"

	diff -u ${draft}.before_edit $draft > ${draft}.edit.diff
	if [ -s ${draft}.edit.diff ] && ! grep -q -i "^+#+doneratio:" ${draft}.edit.diff ; then
		[ "$done_ratio" -eq 100 ] && return
		echo -n "Update DoneRatio from $done_ratio? (0-100 or Enter): "
		read input
		if [ "$input" ] && [ "$input" -ge 0 ] && [ "$input" -le 100 ] ; then
			sed -i "s/^#+doneratio:.*/#+DoneRatio: $input/i" $draft
		fi

		# TODO: Status change caused by done_ratio update
	fi
}

edit_issue3() {
	local issueid="$1"
	local draft="$2"

	while true ; do
		pushd $(dirname $draft)
		"$EDITOR" $draft
		popd
		ask_done_ratio_update3
		diff -u ${draft}.before_edit $draft > ${draft}.edit.diff
		if [ ! "$NO_DOWNLOAD" ] && [ ! -s "${draft}.edit.diff" ] ; then
			echo "no diff, so no need to upload"
			return 1
		fi
		[[ "$issueid" =~ ^L ]] && return 0
		cat ${draft}.edit.diff
		echo
		echo "You really upload this change? (y: yes, n: no, e: edit again)"
		read input
		if [ "$input" == y ] || [ "$input" == Y ] ; then
			return 0
		elif [ "$input" == n ] || [ "$input" == N ] ; then
			return 1 # abort
		else
			true # edit again
		fi
	done
}

update_relations3() {
	local issueid="$1"
	local draftdiff="$2"

	grep -e "^-#+" $draftdiff | cut -c2- > $TMPDIR/tmp.draft.diff.removed
	grep -e "^+#+" $draftdiff | cut -c2- > $TMPDIR/tmp.draft.diff.added

	grep -i -e "^#+relates:" -e "^#+precedes:" -e "^#+blocks:" -e "^#+duplicates:" -e "^#+copied_to:" $TMPDIR/tmp.draft.diff.removed | awk '{print $2}' > $TMPDIR/tmp.draft.diff.remove_id
	for toid in $(cat $TMPDIR/tmp.draft.diff.remove_id) ; do
		echo get_relation_id $issueid A$toid
		local relid=$(get_relation_id $issueid A$toid)
		if [ "$relid" ] ; then
			delete_relation $relid
		fi
	done

	generate_relation_json_from_draft $issueid $TMPDIR/tmp.draft.diff.added | while read line ; do
		echo "$line" > $TMPDIR/relation.json
		create_relation $issueid $TMPDIR/relation.json || exit 1
	done
}

update_issue3() {
	local issueid="$1"
	local draft=$TMPDIR/$RM_DRAFT_FILENAME

	__check_opened $issueid || return 1

	__curl "/issues.json" $TMPDIR/tmp.before_edit "&issue_id=$issueid&include=relations&status_id=*"
	convert_to_draft_from_json $issueid $TMPDIR/tmp.before_edit $draft
	echo "@@@ NOTE @@@ LINES BELOW THIS LINE ARE CONSIDERRED AS NOTES" >> $draft
	cp $draft ${draft}.before_edit

	__open_clock $issueid
	trap "__close_clock $issueid ; exit 0" 2
	while true ; do
		# symlinks for easy access
		ln -s $TMPD/$issueid/.clock.log $TMPDIR/clock
		ln -s $TMPD/$issueid $TMPDIR/cache
		edit_issue3 $issueid $draft || break
		[[ "$issueid" =~ ^L ]] && break
		__curl "/issues.json" $TMPDIR/tmp.after_edit "&issue_id=$issueid&include=relations&status_id=*"
		if cmp --silent $TMPDIR/tmp.before_edit $TMPDIR/tmp.after_edit ; then
			upload_ticket $draft $issueid $TMPDIR/tmp.upload.json
			if [ $? -eq 0 ] ; then
				update_relations3 $issueid ${draft}.edit.diff
				# TODO: need to download forcibly when you update relationship
				# because timestamp might not be updated.
				( update_local_cache_task $ISSUEID ) &
				break
			fi
			echo "update_issue failed, check draft.md and/or network connection."
			echo "type any key to open editor again."
			read input
		else
			convert_to_draft_from_json $issueid $TMPDIR/tmp.after_edit ${draft}.after_edit
			awk '/^@@@ NOTE @@@/{p=1;next}{if(!p){print}}' ${draft}.before_edit > ${draft}.before_edit2
			diff -u ${draft}.before_edit2 ${draft}.after_edit > $TMPDIR/tmp.draft.conflict
			if [ -s "$TMPDIR/tmp.draft.conflict" ] ; then
				echo "### CONFLICT ### YOU NEED TO CONFLICET THE BELOW DIFF MANUALLY" >> $draft
				echo "~~~" >> $draft
				cat $TMPDIR/tmp.draft.conflict >> $draft
				echo "~~~" >> $draft
				echo "Conflict is detected, please resolve it manually."
				echo "type any key to reopen editor again."
				read input
				__curl "/issues.json" $TMPDIR/tmp.before_edit "&issue_id=$issueid&include=relations&status_id=*"
			else
				# 誰かが全く同一の更新を行ったことを意味するので、そのまま抜けてしまって構わない。
				break
			fi
		fi
	done
	__close_clock $issueid
}

generate_issue_template() {
	local tmpfile=$TMPDIR/new/$RM_DRAFT_FILENAME
	mkdir -p $(dirname $tmpfile)

	if [ "$TEMPLATE" ] ; then
		if [ -s "$TEMPLATE" ] ; then
			cat $TEMPLATE | sed -e 's/^#+Status:.*/#+Status: New/' -e 's/^#+DoneRatio:.*/#+DoneRatio: 0/' > $tmpfile
			return
		else
			echo "Template file $TEMPLATE not found"
			exit 1
		fi
	fi

	# echo "#+Issue: $(jq -r .id $tmpjson)" >> $tmpfile
	echo -n "" > $tmpfile
	echo "#+Project: " >> $tmpfile
	echo "#+Subject: subject" >> $tmpfile
	# TODO: tracker/status/priority は設定に応じたデフォルト値を与えるべき -> サーバの設定を利用すべき
	echo "#+Tracker: " >> $tmpfile
	echo "#+Category: null" >> $tmpfile
	echo "#+Status: New" >> $tmpfile
	echo "#+Priority: Normal" >> $tmpfile
	echo "#+ParentIssue: null" >> $tmpfile
	if [ "$RM_USERLIST" ] ; then
		echo "#+Assigned: null" >> $tmpfile
	fi
	echo "#+DoneRatio: 0" >> $tmpfile
	echo "#+Estimate: 1" >> $tmpfile
	# echo "#+DueDate: null" >> $tmpfile
	# echo "#+Category: null" >> $tmpfile
	# echo "#+Version: null" >> $tmpfile
	echo "" >> $tmpfile

	cat $tmpfile
	echo $TMPDIR
}

create_issue2() {
	local tmpfile="$1"

	create_ticket $tmpfile "" $TMPDIR/new/create.json > $TMPDIR/new/create.result.json
	local newissueid=$(jq -r ".issue.id" $TMPDIR/new/create.result.json)
	[ "$newissueid" == null ] && echo "failed to get new ticket ID" && return 1

	# issueid is defined in caller update_issue()
	issueid=$newissueid

	update_relations2 "$issueid" "$draft" || return 1
}

update_new_issue() {
	local draft=$TMPDIR/new/$RM_DRAFT_FILENAME

	echo -n "$(date --iso-8601=seconds) " >> $TMPDIR/new/.clock.log
	trap "__close_clock $issueid ; exit 0" 2
	while true ; do
		pushd $(dirname $draft)
		"$EDITOR" $draft
		popd
		[ "$NEWLOCALTID" ] && break # new local ticket
		echo
		echo "You really upload this change? (y: yes, n: no, e: edit again)"
		read input
		if [ "$input" == y ] || [ "$input" == Y ] ; then
			create_issue2 $draft
			break
		elif [ "$input" == n ] || [ "$input" == N ] ; then
			echo temporary files are stored on $TMPDIR
			break
		else
			true # edit again
		fi
	done
	trap 2
	echo "$(date --iso-8601=seconds)" >> $TMPDIR/new/.clock.log

	if [ "$issueid" ] ; then
		echo "new ticket: $issueid"
		mkdir -p $TMPD/$issueid
		cp $TMPDIR/new/.clock.log $TMPD/$issueid/
		( update_local_cache_task $issueid ) &
	elif [ "$NEWLOCALTID" ] ; then
		echo "new ticket: $NEWLOCALTID"
		mkdir -p $TMPD/$NEWLOCALTID/
		rsync -a $TMPDIR/new/ $TMPD/$NEWLOCALTID/
	fi
}

issueid_to_subject() {
	jq -r ".issues[] | select(.id == $ISSUEID) | .subject" $RM_CONFIG/issues.json
}

declare -A SUBPJ_TABLE
get_project_table() {
	local data=$1

	echo -n "" > $TMPDIR/top_level_projects
	local ifs="$IFS"
	IFS=$'\n'
	for line in $(jq -r ".projects[] | [.id, .parent.id, .status, .subject] | @tsv" $data | sort -k1n) ; do
		local projectid=$(echo $line | cut -f1)
		local parentid=$(echo $line | cut -f2)
		if [ "$parentid" ] ; then
			SUBPJ_TABLE[$parentid]="${SUBPJ_TABLE[$parentid]} $projectid"
		else
			echo $projectid >> $TMPDIR/top_level_projects
		fi
		# TRACKER_TABLE[$taskid]="$(echo $line | cut -f4)"
	done
	IFS="$ifs"
}

__get_subproject() {
	local pj="$1"
	local subpj=

	echo "$pj"
	for subpj in ${SUBPJ_TABLE[$pj]} ; do
		__get_subproject $subpj
	done
}

get_subproject_list() {
	local pj="$@"
	local subpj=

	for subpj in $pj ; do
		__get_subproject $subpj
	done
}

__get_project_tree() {
	local pj="$1"
	local depth="$2"
	local subpj=

	printf "%$[depth*2]s%-4s %s\n" "" "$pj" "$(project_id_to_name $pj)"
	# echo "  $pj => ${SUBPJ_TABLE[$pj]}"
	for subpj in ${SUBPJ_TABLE[$pj]} ; do
		__get_project_tree $subpj $[depth+1]
	done
}

get_project_tree() {
	local subpj=

	for subpj in $@ ; do
		__get_project_tree $subpj 0
	done
}

if [ "$RM_FORMAT" = markdown ] ; then
	RM_DRAFT_FILENAME="draft.md"
else
	RM_DRAFT_FILENAME="draft.textile"
fi

if [ ! "$RM_BASEURL" ] ; then
	echo you need setup RM_BASEURL/RM_KEY
	exit 1
fi
