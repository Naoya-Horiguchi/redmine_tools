if [ ! "$RM_BASEURL" ] ; then
	echo you need setup RM_BASEURL/RM_KEY
	exit 1
fi

mkdir -p $RM_CONFIG

# TODO: support pagination (当面は 1 ページ以内に収まる)
# TODO: version 情報の取得

if ! [ -e "$RM_CONFIG/projects.json" ] || [ "$FORCE_UPDATE" ] ; then
	curl ${INSECURE:+-k} -s "$RM_BASEURL/projects.json?key=${RM_KEY}&limit=100" > $RM_CONFIG/projects.json
	mkdir -p $RM_CONFIG/versions
	for id in $(jq -r ".projects[].id" $RM_CONFIG/projects.json) ; do
		curl ${INSECURE:+-k} -s "$RM_BASEURL/projects/$id/versions.json?key=${RM_KEY}&limit=100" > $RM_CONFIG/versions/${id}.json
	done
fi

if ! [ -e "$RM_CONFIG/priorities.json" ] || [ "$FORCE_UPDATE" ] ; then
	curl ${INSECURE:+-k} -s "$RM_BASEURL/enumerations/issue_priorities.json?key=${RM_KEY}&limit=100" > $RM_CONFIG/priorities.json
fi

if ! [ -e "$RM_CONFIG/trackers.json" ] || [ "$FORCE_UPDATE" ] ; then
	curl ${INSECURE:+-k} -s "$RM_BASEURL/trackers.json?key=${RM_KEY}&limit=100" > $RM_CONFIG/trackers.json
fi

if ! [ -e "$RM_CONFIG/users.json" ] || [ "$FORCE_UPDATE" ] ; then
	curl ${INSECURE:+-k} -s "$RM_BASEURL/users.json?key=${RM_KEY}&limit=100" > $RM_CONFIG/users.json
fi

if ! [ -e "$RM_CONFIG/issue_statuses.json" ] || [ "$FORCE_UPDATE" ] ; then
	curl ${INSECURE:+-k} -s "$RM_BASEURL/issue_statuses.json?key=${RM_KEY}&limit=100" > $RM_CONFIG/issue_statuses.json
fi
