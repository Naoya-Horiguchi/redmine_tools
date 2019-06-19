THISDIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

install: # need root privilege
	ln -sf $(THISDIR)/scripts/edit_issue.sh /usr/local/bin/redmine

uninstall:
	rm -f /usr/local/bin/redmine
