# {
#   "issues": [
#     {
#       "id": 2,
#       "project": {
#         "id": 1,
#         "name": "NVDIMM/pmem"
#       },
#       "tracker": {
#         "id": 5,
#         "name": "Task"
#       },
#       "status": {
#         "id": 10,
#         "name": "Dont"
#       },
#       "priority": {
#         "id": 2,
#         "name": "Normal"
#       },
#       "author": {
#         "id": 5,
#         "name": "hori"
#       },
#       "assigned_to": {
#         "id": 5,
#         "name": "hori"
#       },
#       "subject": "QEMU の NVDIMM 対応",
#       "description": "...",
#       "start_date": "2019-05-22",
#       "due_date": null,
#       "done_ratio": 0,
#       "is_private": false,
#       "estimated_hours": 1,
#       "created_on": "2019-05-22T14:14:10Z",
#       "updated_on": "2020-02-04T05:22:53Z",
#       "closed_on": "2020-02-04T05:22:53Z",
#       "relations": []
#     },

import sys
import json
import csv
import os
import re
import datetime
import pprint

all = False
if sys.argv[1] == "all":
    all = True

with open(os.environ.get('RM_CONFIG') + "/issues.json") as issuedata:
    data = json.load(issuedata)['issues']
with open(os.environ.get('RM_CONFIG') + "/issue_statuses.json") as statusdata:
    status = json.load(statusdata)['issue_statuses']

status_closeness = {}
for st in status:
    status_closeness[st['name']] = st['is_closed']

def check_rule_violation1(elm):
    return elm['status']['name'] == "New" and elm['done_ratio'] != 0

def check_rule_violation2(elm):
    return elm['done_ratio'] == 100 and status_closeness[elm['status']['name']] == False

def check_rule_violation3(elm, status, day, status2):
    updated = datetime.datetime.fromisoformat(elm['updated_on'].replace('Z', '+00:00')).replace(tzinfo=None)
    current = datetime.datetime.now().replace(tzinfo=None)
    tmp = elm['status']['name'] == status and (current - updated).total_seconds() > 86400*day
    if tmp:
        print('%d: more than %d day passed without update, so change status %s -> Dont.' % (elm['id'], day, status))
    return tmp

def check_rule_violation4(elm):
    return elm['status']['name'] == "New" and (elm['start_date'] != None and elm['start_date'] < datetime.date.today().strftime("%Y-%m-%d"))

def check_rule_violation5(elm):
    return status_closeness[elm['status']['name']] == False and (elm['due_date'] != None and elm['due_date'] < datetime.date.today().strftime("%Y-%m-%d"))

def check_rules(elm):
    fail = 0
    # pprint.pprint(elm)
    if check_rule_violation1(elm):
        print('%d: status is New, but done_ratio is >0' % elm['id'])
        fail += 1
    if check_rule_violation2(elm):
        print('%d: done_ratio is 100, but status is open state.' % elm['id'])
        fail += 1
    if check_rule_violation4(elm):
        print('%d: status is New, but start_date is set on older date %s.' % (elm['id'], elm['start_date']))
        fail += 1
    if check_rule_violation5(elm):
        print('%d: ticket is not closed and overdue %s.' % (elm['id'], elm['due_date']))
        fail += 1
    check_rule_violation3(elm, "WIP", 30, "Dont")
    check_rule_violation3(elm, "Wait", 14, "Dont")
    # if fail > 0:
    #     elm.pop('description')
    return fail > 0

# for elm in os.environ.get('RM_RULE_AUTO_WAIT').rsplit(' '):
#     print(elm.rsplit(':'))

if all == False:
    iid = int(sys.argv[1])

rc = 0
for elm in data:
    if all == False and elm['id'] != iid:
        continue
    if check_rules(elm) == True:
        rc = 1

sys.exit(rc)
