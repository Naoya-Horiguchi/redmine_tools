#!/bin/bash

# this script should be sourced from .bashrc.

if [ "$RM_CHANGE_DIRECTORY" == true ] ; then
	redmine() {
		local subcmd="$1"
		local id="$2"
		local thisdir=$(readlink -f $(dirname $BASH_SOURCE))

		# TODO: doesn't work if global option is given.
		if [ "$subcmd" == edit ] ; then
			local issueid=${!#}

			local subject="$(jq -r ".issues[] | select(.id == $issueid) | .subject" $RM_CONFIG/issues.json 2> /dev/null)"
			local project="$(jq -r ".issues[] | select(.id == $issueid) | .project.name" $RM_CONFIG/issues.json 2> /dev/null)"

			if [ "$issueid" ] && [ "$issueid" -ge 0 ] 2> /dev/null ; then
				mkdir -p "$RM_CONFIG/edit_memo/$issueid"
				if [ "$STY" ] ; then
					printf $'\033k'RM#$issueid\($project\)$'\033'\\
				else
					echo -en "\033]2; RM#$issueid ($project): $subject\a"
				fi
				cd $RM_CONFIG/edit_memo/$issueid
				bash $thisdir/scripts/main.sh $@
			else
				bash $thisdir/scripts/main.sh $subcmd -h
				return
			fi
		elif [ "$subcmd" == open ] ; then
			if [ ! "$BROWSER" ] ; then
				echo "you have to set environment variable BROWSER"
				return
			fi
			# In some environment (like WSL), opening browser might fail
			# if it's called from subprocess.
			if [ "$id" -gt 0 ] ; then
				echo "open $RM_BASEURL/issues/$id with browser."
				eval "$BROWSER $RM_BASEURL/issues/$id"
			fi
		elif [ "$subcmd" == dir ] ; then
			local issueid=$2
			if [ -e "$RM_CONFIG/edit_memo/$issueid" ] ; then
				cd $RM_CONFIG/edit_memo/$issueid
			fi
		else
			# TODO: what if argument include "multi word string"?
			bash $thisdir/scripts/main.sh $@
		fi
	}
fi
