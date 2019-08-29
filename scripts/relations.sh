get_relation_id() {
	local id="$1"
	local relstring="$2"

	jq ".issues[] | select(.id == $id) | .relations[] | select((.issue_id == ${relstring:1}) or (.issue_to_id == ${relstring:1})) | .id" $RM_CONFIG/issues.json
}

generate_relation_json() {
	local id="$1"
	local relation_string="$2"

	# TODO: 逆関連
	case $relation_string in
		\-*)
			echo "{\"relation\": {\"issue_to_id\": ${relation_string:1}, \"relation_type\": \"relates\"}}"
			;;
		\>*)
			echo "{\"relation\": {\"issue_to_id\": ${relation_string:1}, \"relation_type\": \"precedes\"}}"
			;;
		\|*)
			echo "{\"relation\": {\"issue_to_id\": ${relation_string:1}, \"relation_type\": \"blocks\"}}"
			;;
		\=*)
			echo "{\"relation\": {\"issue_to_id\": ${relation_string:1}, \"relation_type\": \"duplicates\"}}"
			;;
		\#*)
			echo "{\"relation\": {\"issue_to_id\": ${relation_string:1}, \"relation_type\": \"copied_to\"}}"
			;;
		*)
			echo "no match"
			;;
	esac
}

create_relation() {
	local issueid="$1"
	local file="$2"

	curl ${INSECURE:+-k} -s -X POST -H "Content-Type: application/json" --data-binary "@${file}" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/issues/$issueid/relations.json
}

delete_relation() {
	local relid="$1"

	curl ${INSECURE:+-k} -s -X DELETE -H "Content-Type: application/json" -H "X-Redmine-API-Key: $RM_KEY" $RM_BASEURL/relations/${relid}.json
}

get_relation_string() {
	local tid=$1
	local reltype=$2

	case $reltype in
		relates)
			echo "-$tid"
			;;
		precedes)
			echo ">$tid"
			;;
		blocks)
			echo "|$tid"
			;;
		duplicates)
			echo "=$tid"
			;;
		copied_to)
			echo "#$tid"
			;;
		*)
			echo "$FUNCNAME: invalid reltype: $reltype"
			exit 1
			;;
	esac
}

get_relation_from_server() {
	local issueid="$1"
	local relstring="$2"

	__curl "/issues/${issueid}/relations.json" $TMPDIR/raw_relations.json ""
	jq ".relations[] | select((.issue_id == ${relstring:1}) or (.issue_to_id == ${relstring:1})) | .id" $TMPDIR/raw_relations.json
}

if [[ "$_" =~ bash ]] ; then
	TMPDIR=$(mktemp -d)
	. $(readlink -f $(dirname $BASH_SOURCE))/utils.sh
	echo "testing $BASH_SOURCE"
	generate_relation_json 245 "-252"
	generate_relation_json 245 ">252"
	generate_relation_json 245 "|252"
	generate_relation_json 245 "=252"
	generate_relation_json 245 "#252"
	get_relation_id 245 "#252"
	get_relation_id 252 "=245"
	get_relation_from_server 252 "=245"
fi
