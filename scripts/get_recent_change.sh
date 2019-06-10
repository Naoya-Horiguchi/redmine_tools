if [ ! "$RM_BASEURL" ] ; then
	echo you need setup RM_BASEURL/RM_KEY
	exit 1
fi

REQUESTBASE="$RM_BASEURL/issues.json?key=${RM_KEY}&status_id=*"

if [ -e "$RM_CONFIG/issues.timestamp" ] ; then
	REQUESTBASE="${REQUESTBASE}&updated_on=%3E%3D$(cat $RM_CONFIG/issues.timestamp)"
	# REQUESTBASE="${REQUESTBASE}&updated_on=>=$(cat $RM_CONFIG/issues.timestamp)"
else
	echo call get_issues.sh first.
	exit 1
fi

curl -s "${REQUESTBASE}" | jq .
