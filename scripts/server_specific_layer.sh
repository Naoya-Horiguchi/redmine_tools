# TODO: loading as associative array instead of calling jq

tracker_to_id() {
	jq -r ".trackers[] | select(.name|test(\"$1\";\"i\")) | .id" $RM_CONFIG/trackers.json
}

tracker_to_name() {
	jq -r ".trackers[] | select(.id == $1) | .name" $RM_CONFIG/trackers.json
}

trackerspec_to_trackerid() {
	local spec="$1"
	local re='^[0-9]+$'

	if [[ "$spec" =~ $re ]] ; then
		echo "$spec"
	else
		# TODO: if found multiple record? -> first match
		# TODO: escape input? what if pjspec contains ','?
		jq -r ".trackers[] | select(.name|test(\"$spec\";\"i\")) | .id" $RM_CONFIG/trackers.json
	fi
}

categoryspec_to_categoryid() {
	local spec="$1"
	local re='^[0-9]+$'

	if [[ "$spec" =~ $re ]] ; then
		echo "$spec"
	else
		jq -r ". | select(.name|test(\"$spec\";\"i\")) | .id" $RM_CONFIG/issue_categories.json
	fi
}

project_to_id() {
	jq -r ".projects[] | select(.name == \"$1\") | .id" $RM_CONFIG/projects.json
}

project_to_name() {
	jq -r ".projects[] | select(.id == $1) | .name" $RM_CONFIG/projects.json
}

# TODO: duplicate input, sort
pjspec_to_pjid() {
	local re='^[0-9]+$'
	local out=
	for i in $(seq $#) ; do
		tmp="$1"
		if [[ "$tmp" =~ $re ]] ; then
			out="$out $tmp"
		else
			# TODO: escape input? what if pjspec contains ','?
			tmp2="$(jq -r ".projects[] | select(.name|test(\"^$tmp$\";\"i\")) | .id" $RM_CONFIG/projects.json)"
			# 完全一致するプロジェクトが存在しないときは部分一致でマッチする。複数ヒットすることがある。
			if [ ! "$tmp2" ] ; then
				tmp2="$(jq -r ".projects[] | select(.name|test(\"$tmp\";\"i\")) | .id" $RM_CONFIG/projects.json)"
			fi
			out="$out $tmp2"
		fi
		shift
	done
	echo $out
}

priority_to_id() {
	jq -r ".issue_priorities[] | select(.name == \"$1\") | .id" $RM_CONFIG/priorities.json
}

priority_to_name() {
	jq -r ".issue_priorities[] | select(.id == $1) | .name" $RM_CONFIG/priorities.json
}

priorityspec_to_priorityid() {
	local spec="$1"
	local re='^[0-9]+$'

	if [[ "$spec" =~ $re ]] ; then
		echo "$spec"
	else
		# TODO: if found multiple record? -> first match
		# TODO: escape input? what if pjspec contains ','?
		jq -r ".issue_priorities[] | select(.name|test(\"$spec\";\"i\")) | .id" $RM_CONFIG/priorities.json
	fi
}

status_to_id() {
	jq -r ".issue_statuses[] | select(.name|test(\"$1\";\"i\")) | .id" $RM_CONFIG/issue_statuses.json
}

status_to_name() {
	jq -r ".issue_statuses[] | select(.id == $1) | .name" $RM_CONFIG/issue_statuses.json
}

status_closed() {
	local closed=$(jq -r ".issue_statuses[] | select(.name == \"$1\") | .is_closed" $RM_CONFIG/issue_statuses.json)
	[ "$closed" == true ] && return 0 || return 1
}

statusspec_to_statusid() {
	local spec="$1"
	local re='^[0-9]+$'

	if [[ "$spec" =~ $re ]] ; then
		echo "$spec"
	else
		# TODO: if found multiple record? -> first match
		# TODO: escape input? what if pjspec contains ','?
		jq -r ".issue_statuses[] | select(.name|test(\"^$spec\";\"i\")) | .id" $RM_CONFIG/issue_statuses.json
	fi
}

user_to_id() {
	jq -r ".users[] | select(.login == \"$1\") | .id" $RM_CONFIG/users.json
}

user_to_name() {
	jq -r ".users[] | select(.id == $1) | .login" $RM_CONFIG/users.json
}

userspec_to_userid() {
	local spec="$1"
	local re='^[0-9]+$'

	if [ ! "$spec" ]  ; then
		return
	fi
	if [[ "$spec" =~ $re ]] ; then
		echo "$spec"
	else
		# TODO: if found multiple record? -> first match
		# TODO: escape input? what if pjspec contains ','?
		jq -r ".users[] | select(.login|test(\"$spec\";\"i\")) | .id" $RM_CONFIG/users.json
	fi
}

issueid_to_subject() {
	jq -r ".issues[] | select(.id == $1) | .subject" $RM_CONFIG/issues.json
}

issueid_to_pjid() {
	jq -r ".issues[] | select(.id == $1) | .project.id" $RM_CONFIG/issues.json
}

issueid_to_done_ratio() {
	jq -r ".issues[] | select(.id == $1) | .done_ratio" $RM_CONFIG/issues.json
}

tracker_to_default_status_name() {
	jq -r ".trackers[] | select(.id == $1) | .default_status.name" $RM_CONFIG/trackers.json
}

# TODO: add some for version
