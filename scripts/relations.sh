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

get_json_string() {
	local issueid="$1"
	local issuetoid="$2"
	local reltype="$3"
	echo "{\"relation\": {\"issue_to_id\": \"$issuetoid\", \"relation_type\": \"$reltype\"}}"
}

# input: draft file
# output: json string (might be more than one)
generate_relation_json_from_draft() {
	local id="$1"
	local draft="$2"

	# TODO: 逆関連
	local relates="$(grep -i ^#+relates: "$draft" | sed 's|^#+relates: *||i' | tr '\n' ' ')"
	local precedes="$(grep -i ^#+precedes: "$draft" | sed 's|^#+precedes: *||i' | tr '\n' ' ')"
	local blocks="$(grep -i ^#+blocks: "$draft" | sed 's|^#+blocks: *||i' | tr '\n' ' ')"
	local duplicates="$(grep -i ^#+duplicates: "$draft" | sed 's|^#+duplicates: *||i' | tr '\n' ' ')"
	local copied_to="$(grep -i ^#+copied_to: "$draft" | sed 's|^#+copied_to: *||i' | tr '\n' ' ')"

	local follows="$(grep -i ^#+follows: "$draft" | sed 's|^#+follows: *||i' | tr '\n' ' ')"
	local blocked="$(grep -i ^#+blocked: "$draft" | sed 's|^#+blocked: *||i' | tr '\n' ' ')"
	local duplicated="$(grep -i ^#+duplicated: "$draft" | sed 's|^#+duplicated: *||i' | tr '\n' ' ')"
	local copied_from="$(grep -i ^#+copied_from: "$draft" | sed 's|^#+copied_from: *||i' | tr '\n' ' ')"

	for toid in $relates      ; do get_json_string "$id" "$toid" relates ; done
	for toid in $blocks       ; do get_json_string "$id" "$toid" blocks ; done
	for toid in $precedes     ; do get_json_string "$id" "$toid" precedes ; done
	for toid in $duplicates   ; do get_json_string "$id" "$toid" duplicates ; done
	for toid in $copied_to    ; do get_json_string "$id" "$toid" copied_to ; done
	for toid in $follows      ; do get_json_string "$toid" "$id" follows ; done
	for toid in $blocked      ; do get_json_string "$toid" "$id" blocked ; done
	for toid in $duplicated   ; do get_json_string "$toid" "$id" duplicated ; done
	for toid in $copied_from  ; do get_json_string "$toid" "$id" copied_from ; done
}

generate_relations_cache() {
	jq -r '.issues[].relations[] | [.issue_id, .relation_type, .issue_to_id, .id] | @tsv' $RM_CONFIG/issues.json | sort | uniq
}


get_relationship() {
	local relation=$1

	case $relation in
		"->")
			relation=precedes
			;;
		"<-")
			relation=follows
			;;
		-o)
			relation=blocks
			;;
		o-)
			relation=blocked
			;;
		-c)
			relation=copied_to
			;;
		c-)
			relation=copied_from
			;;
		-)
			relation=relates
			;;
		"=>")
			relation=duplicates
			;;
		"<=")
			relation=duplicated
			;;
	esac
	echo $relation
}

get_reverse_relation() {
	local relation=$1

	case $relation in
		precedes)
			echo follows
			;;
		follows)
			echo precedes
			;;
		blocks)
			echo blocked
			;;
		blocked)
			echo blocks
			;;
		copied_to)
			echo copied_from
			;;
		copied_from)
			echo copied_to
			;;
		relates)
			echo relates
			;;
		duplicates)
			echo duplicated
			;;
		duplicated)
			echo duplicates
			;;
	esac
}

create_one_relation() {
	local string=$1

	local id1=$(echo $string | sed -e 's/[^0-9]/ /g' | awk '{print $1}')
	local id2=$(echo $string | sed -e 's/[^0-9]/ /g' | awk '{print $2}')
	local relation=$(echo $string | sed -e 's/[0-9]//g')
	if [ ! "$id2" ] || [ ! "$relation" ] ; then
		echo "invalid input: $string" >&2
		show_help
		return 1
	fi

	relation=$(get_relationship $relation)
	echo "[$id1] => [$id2] $relation"
	create_relation $id1 <(get_json_string "$id1" "$id2" $relation)
	update_local_cache_tasks $id1 $id2
}

delete_one_relation() {
	local string=$1
	local id1=
	local id2=

	if [[ "$string" =~ ^[0-9]+$ ]] ; then
		# specified with notation
		echo "deleting relation ID $string"
		delete_relation $string
		if [ $? -eq 0 ] ; then
			id1=$(grep -P "\t${string}$" $TMPDIR/relation.tsv | cut -f1)
			id2=$(grep -P "\t${string}$" $TMPDIR/relation.tsv | cut -f3)
			update_local_cache_tasks $id1 $id2
		fi
	else
		# specified with relation ID
		echo "deleting relation \"$string\""

		id1=$(echo $string | sed -e 's/[^0-9]/ /g' | awk '{print $1}')
		id2=$(echo $string | sed -e 's/[^0-9]/ /g' | awk '{print $2}')
		local relation=$(echo $string | sed -e 's/[0-9]//g')
		relation=$(get_relationship $relation)

		local rid=$(grep -P "^$id1\t$relation\t$id2" $TMPDIR/relation.tsv | cut -f4)
		if [ ! "$rid" ] ; then
			relation=$(get_reverse_relation $relation)
			rid=$(grep -P "^$id2\t$relation\t$id1" $TMPDIR/relation.tsv | cut -f4)
		fi

		if [ "$rid" ] ; then
			echo "delete_relation $rid ($string)"
			delete_relation $rid
			update_local_cache_tasks $id1 $id2
		else
			echo "failed to get relation ID of \"$string\""
		fi
	fi
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
	cat <<EOF > $TMPDIR/draft.md
ad
#+Blocks: 30
#+Blocks: 23
#+Precedes: 34
afadf
af
EOF
	generate_relation_json_from_draft 72 $TMPDIR/draft.md
fi
