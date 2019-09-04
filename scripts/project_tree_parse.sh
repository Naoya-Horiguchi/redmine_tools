ARRAY=()
PJARRAY=()

declare -A NEW_PARENT_TABLE;
declare -A NEW_PARENT_PJ_TABLE;
declare -A NEW_PJ_TABLE;

ifs="$IFS"
IFS=$'\n'
id=
relprevdepth=0
pj=
prevpjdepth=-1
prevpj=
reldepth=0
relprevdepth=-1
previd=

TARGETFILE=$1
[ ! "$TARGETFILE" ] && echo "need to give project tree file" && exit 1

for line in $(cat $TARGETFILE) ; do
	indent=$(expr match "$line" " *")
	id=$(echo $line | awk '{print $1}')
	depth=$[indent/2]

	if [[ "$id" =~ ^PJ ]] ; then
		pj=$id

		if [ "$depth" -eq "$[prevpjdepth+1]" ] ; then # deeper
			PJARRAY+=($prevpj)
			if [ "$prevpj" ] ; then
				NEW_PARENT_PJ_TABLE[$pj]=${PJARRAY[-1]}
			fi
		elif [ "$depth" -eq "$prevpjdepth" ] ; then # same level
			if [ "$depth" -gt 0 ] ; then
				NEW_PARENT_PJ_TABLE[$pj]=${PJARRAY[-1]}
			fi
		elif [ "$depth" -lt "$prevpjdepth" ] ; then # shallower
			PJARRAY=( ${PJARRAY[@]::${depth}} )
			if [ "$depth" -gt 0 ] ; then
				NEW_PARENT_PJ_TABLE[$pj]=${PJARRAY[-1]}
			fi
		fi

		prevpjdepth=$depth
		prevpj=$pj
		ARRAY=()
		relprevdepth=-1
		previd=
	else
		reldepth=$[depth-prevpjdepth-1]
		NEW_PJ_TABLE[$id]=$pj
		if [ "$reldepth" -lt 0 ] || [ "$[reldepth-relprevdepth]" -gt 1 ] ; then
			echo "invalid depth: task should be deeper than project header"
			exit 1
		elif [ "$reldepth" -eq "$relprevdepth" ] ; then # same level
			if [ "$reldepth" -gt 0 ] ; then
				NEW_PARENT_TABLE[$id]=${ARRAY[-1]}
			fi
		elif [ "$reldepth" -eq "$[relprevdepth+1]" ] ; then # deeper
			ARRAY+=($previd)
			if [ "$previd" ] ; then
				NEW_PARENT_TABLE[$id]=${ARRAY[-1]}
			fi
		elif [ "$reldepth" -lt "$relprevdepth" ] ; then # shallower
			ARRAY=( ${ARRAY[@]::${reldepth}} )
			if [ "$reldepth" -gt 0 ] ; then
				NEW_PARENT_TABLE[$id]=${ARRAY[-1]}
			fi
		else
			echo "invalid indentation" >&2
			exit 1
		fi
		relprevdepth=$reldepth
		previd=$id
	fi
	# echo "${line::13} ---> $reldepth, $relprevdepth || ${PJARRAY[@]} || ${ARRAY[@]}"
	# echo "[ $depth/$prevpjdepth/$reldepth: ; $line ${ARRAY[@]}"
done
IFS="$ifs"

for x in ${!NEW_PARENT_TABLE[@]} ; do
	echo "$x parenttask ${NEW_PARENT_TABLE[$x]}"
done
for x in ${!NEW_PARENT_PJ_TABLE[@]} ; do
	echo "$x parentpj ${NEW_PARENT_PJ_TABLE[$x]}"
done
for x in ${!NEW_PJ_TABLE[@]} ; do
	echo "$x newpj ${NEW_PJ_TABLE[$x]}"
done
