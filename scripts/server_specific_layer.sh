# TODO: loading as associative array instead of calling jq

tracker_to_id() {
	jq -r ".trackers[] | select(.name == \"$1\") | .id" $RM_CONFIG/trackers.json
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

project_to_id() {
	jq -r ".projects[] | select(.name == \"$1\") | .id" $RM_CONFIG/projects.json
}

project_to_name() {
	jq -r ".projects[] | select(.id == $1) | .name" $RM_CONFIG/projects.json
}

pjspec_to_pjid() {
	local specs="$@"
	local re='^[0-9]+$'
	local spec=
	local out=

	for spec in $specs ; do
		if [[ "$spec" =~ $re ]] ; then # if number, it's pjid itself.
			out="$out $spec"
		else
			# TODO: escape input? what if pjspec contains ','?
			out="$out $(jq -r ".projects[] | select(.name|test(\"^$spec$\";\"i\")) | .id" $RM_CONFIG/projects.json)"
			# 完全一致するプロジェクトが存在しないときは部分一致でマッチする。複数ヒットすることがある。
			if [ "$out" == " " ] ; then
				out="$out $(jq -r ".projects[] | select(.name|test(\"$spec\";\"i\")) | .id" $RM_CONFIG/projects.json)"
			fi
		fi
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
	jq -r ".issue_statuses[] | select(.name == \"$1\") | .id" $RM_CONFIG/issue_statuses.json
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
		jq -r ".issue_statuses[] | select(.name|test(\"$spec\";\"i\")) | .id" $RM_CONFIG/issue_statuses.json
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

	if [[ "$spec" =~ $re ]] ; then
		echo "$spec"
	else
		# TODO: if found multiple record? -> first match
		# TODO: escape input? what if pjspec contains ','?
		jq -r ".users[] | select(.name|test(\"$spec\";\"i\")) | .id" $RM_CONFIG/users.json
	fi
}

issueid_to_subject() {
	jq -r ".issues[] | select(.id == $1) | .subject" $RM_CONFIG/issues.json
}

issueid_to_pjid() {
	jq -r ".issues[] | select(.id == $1) | .project.id" $RM_CONFIG/issues.json
}

# TODO: add some for version
