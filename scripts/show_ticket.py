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

tracker_id_to_name = {}
with open(os.environ.get('RM_CONFIG')+ '/trackers.json') as json_file:
    data = json.load(json_file)
    for d in data['trackers']:
        tracker_id_to_name[d['id']] = d['name']

status_id_to_name = {}
with open(os.environ.get('RM_CONFIG')+ '/issue_statuses.json') as json_file:
    data = json.load(json_file)
    for d in data['issue_statuses']:
        status_id_to_name[d['id']] = d['name']

project_id_to_name = {}
with open(os.environ.get('RM_CONFIG')+ '/projects.json') as json_file:
    data = json.load(json_file)
    for d in data['projects']:
        project_id_to_name[d['id']] = d['name']

priority_id_to_name = {}
with open(os.environ.get('RM_CONFIG')+ '/priorities.json') as json_file:
    data = json.load(json_file)
    for d in data['issue_priorities']:
        priority_id_to_name[d['id']] = d['name']

user_id_to_name = {}
with open(os.environ.get('RM_CONFIG')+ '/users.json') as json_file:
    data = json.load(json_file)
    for d in data['users']:
        user_id_to_name[d['id']] = d['login']

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
if 'start_date' in issue.keys():
    print("#+StartDate: %s" % issue['start_date'])
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

def print_attr(name, old, new):
    if name == 'tracker_id':
        name = 'Tracker'
        if int(old) in tracker_id_to_name:
            old = tracker_id_to_name[int(old)]
        if int(new) in tracker_id_to_name:
            new = tracker_id_to_name[int(new)]
    if name == 'status_id':
        name = 'Status'
        if int(old) in status_id_to_name:
            old = status_id_to_name[int(old)]
        if int(new) in status_id_to_name:
            new = status_id_to_name[int(new)]
    if name == 'project_id':
        name = 'Project'
        if int(old) in project_id_to_name:
            old = project_id_to_name[int(old)]
        if int(new) in project_id_to_name:
            new = project_id_to_name[int(new)]
    if name == 'priority_id':
        name = 'Priority'
        if int(old) in priority_id_to_name:
            old = priority_id_to_name[int(old)]
        if int(new) in priority_id_to_name:
            new = priority_id_to_name[int(new)]
    if name == 'assigned_to_id':
        name = 'Assigned'
        if old != None:
            old = user_id_to_name[int(old)]
        if new != None:
            new = user_id_to_name[int(new)]
    print('    %s: %s -> %s' % (name, old, new))

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
            print_attr(attr['name'], attr['old_value'], attr['new_value'])
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
