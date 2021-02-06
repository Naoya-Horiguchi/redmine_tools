import sys
import json
import os
import re
import csv

showClosed = False
showColor= False
showSubproject = False
projects = None
tickets = None
grouping = False
relationFile = None
if os.environ.get('SHOWCLOSED') and re.match(r'true', os.environ.get('SHOWCLOSED'), re.IGNORECASE):
    showClosed = True
if os.environ.get('COLOR') and re.match(r'true', os.environ.get('COLOR'), re.IGNORECASE):
    showColor = True
if os.environ.get('SHOWSUBPROJECT') and re.match(r'true', os.environ.get('SHOWSUBPROJECT'), re.IGNORECASE):
    showSubproject = True
if os.environ.get('PROJECTS'):
    projects = list(map(int, os.environ.get('PROJECTS').rsplit(',')))
if os.environ.get('TICKETS'):
    tickets = list(map(int, os.environ.get('TICKETS').rsplit(',')))
if os.environ.get('GROUPING') and re.match(r'true', os.environ.get('GROUPING'), re.IGNORECASE):
    grouping = True
if os.environ.get('RELATIONS'):
    relationFile = os.environ.get('RELATIONS')

subjects = {}
trackers = {}
status = {}
ratios = {}
updateds = {}
closeds = {}
pjs = {}
prios = {}

pjIds = {}
pjNames = {}
globalIds = []

fg = lambda text, color: "\33[38;5;" + str(color) + "m" + text + "\33[0m"
bg = lambda text, color: "\33[48;5;" + str(color) + "m" + text + "\33[0m"

def print_six(row, format):
    for col in range(6):
        color = row*6 + col + 4
        if color>=0:
            text = "{:3d}".format(color)
            print (format(text,color), end=" ")
        else:
            print("   ", end=" ")

# for row in range(-1,42):
#     print_six(row, fg)
#     print("",end=" ")
#     print_six(row, bg)
#     print()

pjParent = {}
pjIncluded = {}
with open(sys.argv[2]) as proj_json:
    data = json.load(proj_json)
    for pj in data['projects']:
        if 'parent' in pj:
            pjParent[pj['id']] = pj['parent']['id']
    for pj in data['projects']:
        pjid = pj['id']
        pjid2 = pjid
        while True:
            if projects and pjid in projects:
                pjIncluded[pjid2] = True
                break
            if showSubproject and (pjid in pjParent):
                pjid = pjParent[pjid]
            else:
                break

defaultTracker = {}
trackerColor = {}
i = 1
with open(sys.argv[3]) as tracker_json:
    data = json.load(tracker_json)
    for tracker in data['trackers']:
        trackerColor[tracker['name']] = i
        i += 1
        defaultTracker[tracker['name']] = tracker['default_status']['name']

statusClosed = {}
with open(sys.argv[4]) as status_json:
    data = json.load(status_json)
    for status in data['issue_statuses']:
        if 'is_closed' in status:
            statusClosed[status['name']] = status['is_closed']

with open(sys.argv[1]) as json_file:
    data = json.load(json_file)
    for p in data['issues']:
        tid = p['id']
        pjid = p['project']['id']
        if not pjid in pjIds.keys():
            pjIds[pjid] = []
        if not pjid in pjNames.keys():
            pjNames[pjid] = p['project']['name']
        if p['status']['name'] in statusClosed and statusClosed[p['status']['name']] == True and showClosed == False:
            continue
        if projects and not pjid in pjIncluded:
            continue
        pjIds[pjid].append(tid)
        globalIds.append(tid)
        subjects[tid] = p['subject']
        trackers[tid] = p['tracker']['name']
        if p['status']['name'] in statusClosed and statusClosed[p['status']['name']] == True:
            closeds[tid] = True
        else:
            closeds[tid] = None
        ratios[tid] = int(p['done_ratio'])
        prios[tid] = p['priority']['id']
        if showColor == True:
            if closeds[tid]:
                status[tid] = fg(p['status']['name'], 238)
            elif p['status']['name'] == defaultTracker[trackers[tid]]:
                status[tid] = fg(p['status']['name'], 200)
            else:
                status[tid] = fg(p['status']['name'], 228)
            if ratios[tid] == 0:
                ratios[tid] = fg(str(ratios[tid]), 200)
            elif ratios[tid] == 100:
                ratios[tid] = fg(str(ratios[tid]), 48)
            else:
                ratios[tid] = fg(str(ratios[tid]), 228)
            trackers[tid] = fg(trackers[tid], trackerColor[trackers[tid]])
        else:
            status[tid] = p['status']['name']
            ratios[tid] = str(ratios[tid])
        updateds[tid] = p['updated_on']
        pjs[tid] = pjid

def priority_color(prio):
    if showColor != True:
        return prio
    if prio == 1:
        return fg(str(prio), 8)
    elif prio == 2:
        return fg(str(prio), 4)
    elif prio == 3:
        return fg(str(prio), 2)
    elif prio == 4:
        return fg(str(prio), 3)
    elif prio == 5:
        return fg(str(prio), 1)

relations = {}
if relationFile:
    with open(relationFile) as tsv_file:
        tsv = csv.reader(tsv_file, delimiter="\t")
        for row in tsv:
            if not row[0] in relations.keys():
                relations[row[0]] = []
            if not row[2] in relations.keys():
                relations[row[2]] = []
            if row[1] == "relates":
                relations[row[0]].append("-%s" % (row[2]))
                relations[row[2]].append("-%s" % (row[0]))
            elif row[1] == "blocks":
                relations[row[0]].append("-o%s" % (row[2]))
                relations[row[2]].append("o-%s" % (row[0]))
            elif row[1] == "precedes":
                relations[row[0]].append("->%s" % (row[2]))
                relations[row[2]].append("<-%s" % (row[0]))
            elif row[1] == "duplicates":
                relations[row[0]].append("=>%s" % (row[2]))
                relations[row[2]].append("<=%s" % (row[0]))
            elif row[1] == "copied_to":
                relations[row[0]].append("-c%s" % (row[2]))
                relations[row[2]].append("c-%s" % (row[0]))
            else:
                print("unknown relation %s\n", row)
    for rel in relations:
        relations[rel] = ",".join(relations[rel])
        if relations[rel] != "":
            relations[rel] = "(%s) " % (relations[rel])
            if showColor == True:
                relations[rel] = fg(relations[rel], 37)

def take_updated_on(tid):
    return (prios[tid], updateds[tid])

def show_project(pj):
    print("PJ%d %s" % (pj, pjNames[pj]))
    sorted_tids = sorted(pjIds[pj], key=take_updated_on)
    for tid in sorted_tids:
        show_ticket(tid, False)
    print("")

def show_ticket(tid, showPj):
    rel = ""
    if str(tid) in relations.keys():
        rel = relations[str(tid)]
    if showPj:
        print("%s\tPJ%d\t<%s|%s|%s|%s>\t%d%s\t%s" % (updateds[tid][2:-4], pjs[tid], trackers[tid], status[tid], ratios[tid], priority_color(prios[tid]), tid, rel, subjects[tid]))
    else:
        print("%s\t<%s|%s|%s|%s>\t%d%s\t%s" % (updateds[tid][2:-4], trackers[tid], status[tid], ratios[tid], priority_color(prios[tid]), tid, rel, subjects[tid]))

if not grouping:
    sorted_tids = sorted(globalIds, key=take_updated_on)
    for tid in sorted_tids:
        show_ticket(tid, True)
elif projects:
    for pj in projects:
        show_project(pj)
else:
    for pj in pjIds.keys():
        show_project(pj)
