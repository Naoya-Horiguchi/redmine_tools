THISDIR=$(readlink -f $(dirname $BASH_SOURCE))
. $THISDIR/utils.sh

generate_project_table PJTABLE

find $RM_CONFIG/edit_memo -type d | grep LOCAL | while read line ; do
	id=$(basename $line)
	subject="$(grep -i ^#\+subject: $line/draft.md | sed 's|^#+subject: *||i')"
	project="$(grep -i ^#\+project: $line/draft.md | sed 's|^#+project: *||i')"

	echo -e "$id\t${PJTABLE[$project]}\t$subject"
done | column -t -s $'\t' | sort
