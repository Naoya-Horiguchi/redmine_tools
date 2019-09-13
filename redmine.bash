#!/bin/bash

# this script should be sourced from .bashrc.

redmine() {
	local subcmd="$1"
	local id="$2"
	local thisdir=$(readlink -f $(dirname $BASH_SOURCE))

	# TODO: doesn't work if global option is given.
	if [ "$subcmd" == edit ] ; then
		local issueid=$2
		local subject="$(jq -r ".issues[] | select(.id == $issueid) | .subject" $RM_CONFIG/issues.json)"
		if [ -e "$RM_CONFIG/edit_memo/$issueid" ] ; then
			[ "$subject" ] && echo -e '\033]2;'"Redmine#$issueid $subject"'\007'
			cd $RM_CONFIG/edit_memo/$issueid
			bash $thisdir/scripts/main.sh $@
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
