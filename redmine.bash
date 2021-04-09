#!/bin/bash

# this script should be sourced from .bashrc.

if [ "$STY" ] ; then
	_catch_child_termination() {
		if ! pgrep -P $$ > /dev/null ; then
			[ "$STY" ] && PROMPT_COMMAND="$KEEP_PROMPT_COMMAND"
		fi
	}
fi

redmine() {
	local thisdir=$(readlink -f $(dirname $BASH_SOURCE))

	if [ "$STY" ] ; then
		KEEP_PROMPT_COMMAND="$PROMPT_COMMAND"
		PROMPT_COMMAND='_catch_child_termination'
		local tag="$(echo $@ | sed 's/ /_/g')"
		printf $'\033k'RM_$tag$'\033'\\
	fi

	# server subcommand could update environment variable, so
	# need to execute in this shell (not in the subshell).
	if [ "$1" == "server" ] || [ "$1" == "relation" ] ; then
		. $thisdir/scripts/main.sh
		return 0
	fi

	local args=
	for a in "$@" ; do
		if [[ "$a" =~ ' ' ]] ; then
			args="$args \"$a\""
		else
			args="$args $a"
		fi
	done
	eval bash $thisdir/scripts/main.sh $args
}
