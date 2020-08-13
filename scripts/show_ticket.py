import sys
import json
import os
import re

import urllib.request
import ssl
import pprint
pp = pprint.PrettyPrinter(indent=2)

fg = lambda text, color: "\33[38;5;" + str(color) + "m" + text + "\33[0m"
bg = lambda text, color: "\33[48;5;" + str(color) + "m" + text + "\33[0m"

showJournals = False
if os.environ.get('SHOW_JOURNALS') and re.match(r'true', os.environ.get('SHOW_JOURNALS'), re.IGNORECASE):
    showJournals = True

scontext = ssl.SSLContext(ssl.PROTOCOL_TLS)
url = "%s/issues.json?key=%s&issue_id=605&include=relations&status_id=*" % (os.environ.get('RM_BASEURL'), os.environ.get('RM_KEY'))
url = "%s/issues/%s.json?key=%s&include=journals" % (os.environ.get('RM_BASEURL'), sys.argv[1], os.environ.get('RM_KEY'))
header = {}

opener = urllib.request.build_opener()
opener.addheaders = [('Accept', 'application/json')]
urllib.request.install_opener(opener)

response = urllib.request.urlopen(url, context=scontext)
data = response.read()
text = data.decode('utf-8')
encoding = response.info().get_content_charset('utf-8')
text = json.loads(data.decode(encoding))

issue = text['issue']

print("#+Issue: %s" % issue['id'])
print("#+DoneRatio: %s" % issue['done_ratio'])
print("#+Status: %s" % issue['status']['name'])
print("#+Subject: %s" % issue['subject'])
print("#+Project: %s" % issue['project']['name'])
print("#+Tracker: %s" % issue['tracker']['name'])
if 'category' in issue.keys():
    print("#+Category: %s" % issue['category']['name'])
print("#+Priority: %s" % issue['priority']['name'])
if 'parent' in issue.keys():
    print("#+ParentIssue: %s" % issue['parent']['id'])
if 'assigned_to' in issue.keys():
    print("#+Assigned: %s" % issue['assigned_to']['name'])
if 'estimated_hours' in issue.keys():
    print("#+Estimate: %s" % issue['estimated_hours'])
if 'due_date' in issue.keys():
    print("#+DueDate: %s" % issue['due_date'])

if issue['description']:
    print(issue['description'].replace('\r', ''))

def print_six(row, format):
    for col in range(6):
        color = row*6 + col + 4
        if color>=0:
            text = "{:3d}".format(color)
            print (format(text,color), end=" ")
        else:
            print("   ", end=" ")

if showJournals != True:
    exit(0)

import difflib
for journal in reversed(issue['journals']):
    print(bg(fg("Journal ID: %s" % journal['id'], 11), 102))
    print(fg("Author: %s" % journal['user']['name'], 150))
    print(fg("Date: %s" % journal['created_on'], 213))
    attrs = []
    descChange = False
    for detail in journal['details']:
        if detail['property'] != 'attr':
            continue
        if detail['name'] == 'description':
            descChange = detail
        else:
            attrs.append(detail)

    if attrs or journal['notes']:
        print("")
        for attr in attrs:
            print('    %s: %s -> %s' % (attr['name'], attr['old_value'], attr['new_value']))
        if journal['notes']:
            print("")
            print(re.sub('^', ' '*4, journal['notes'], flags=re.MULTILINE))
        print("")
    if descChange:
        if not descChange['old_value']:
            descChange['old_value'] = ''
        if not descChange['new_value']:
            descChange['new_value'] = ''
        for line in difflib.unified_diff(descChange['old_value'].replace('\r', '').split('\n'), descChange['new_value'].replace('\r', '').split('\n')):
            if line == '--- \n' or line == '+++ \n':
                continue
            if line[0] == '@':
                print(fg(line.rstrip(), 3))
            elif line[0] == '+':
                print(fg(line, 2))
            elif line[0] == '-':
                print(fg(line, 1))
            else:
                print(line)

# blocked
# blocks
# copied_from
# copied_to
# duplicated
# duplicates
# follows
# precedes
# relates
