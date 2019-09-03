# TODO: loading as associative array instead of calling jq

tracker_to_id() {
	jq -r ".trackers[] | select(.name == \"$1\") | .id" $RM_CONFIG/trackers.json
}

tracker_to_name() {
	jq -r ".trackers[] | select(.id == $1) | .name" $RM_CONFIG/trackers.json
}

project_to_id() {
	jq -r ".projects[] | select(.name == \"$1\") | .id" $RM_CONFIG/projects.json
}

project_to_name() {
	jq -r ".projects[] | select(.id == $1) | .name" $RM_CONFIG/projects.json
}

priority_to_id() {
	jq -r ".issue_priorities[] | select(.name == \"$1\") | .id" $RM_CONFIG/priorities.json
}

priority_to_name() {
	jq -r ".issue_priorities[] | select(.id == $1) | .name" $RM_CONFIG/priorities.json
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

user_to_id() {
	jq -r ".users[] | select(.login == \"$1\") | .id" $RM_CONFIG/users.json
}

user_to_name() {
	jq -r ".users[] | select(.id == $1) | .login" $RM_CONFIG/users.json
}
