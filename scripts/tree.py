import sys
import csv
import os
import re
import json

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

showClosed = False
showColor= False
showSubproject = False
showPjonly = False
projects = None
tickets = None
relationFile = None
if os.environ.get('SHOWCLOSED') and re.match(r'true', os.environ.get('SHOWCLOSED'), re.IGNORECASE):
    showClosed = True
if os.environ.get('COLOR') and re.match(r'true', os.environ.get('COLOR'), re.IGNORECASE):
    showColor = True
if os.environ.get('SHOWSUBPROJECT') and re.match(r'true', os.environ.get('SHOWSUBPROJECT'), re.IGNORECASE):
    showSubproject = True
if os.environ.get('SHOWPJONLY') and re.match(r'true', os.environ.get('SHOWPJONLY'), re.IGNORECASE):
    showPjonly = True
if os.environ.get('PROJECTS'):
    projects = list(map(int, os.environ.get('PROJECTS').rsplit(',')))
if os.environ.get('TICKETS'):
    tickets = list(map(int, os.environ.get('TICKETS').rsplit(',')))
if os.environ.get('RELATIONS'):
    relationFile = os.environ.get('RELATIONS')

trackers = {}
status = {}
ratios = {}
subjects = {}
closeds = {}
prios = {}

topPjs = []
pjTree = {}
pjNames = {}
pjTopIds = {}
with open(sys.argv[2]) as csvDataFile:
    csvReader = csv.reader(csvDataFile)
    for row in csvReader:
        pjid = int(row[1])
        pjNames[pjid] = row[2]
        pjTopIds[pjid] = []
        if not pjid in pjTree.keys():
            pjTree[pjid] = []
        if not row[0]: # top level project
            topPjs.append(pjid)
        else:
            pid = int(row[0])
            if pid in pjTree:
                pjTree[pid].append(pjid)
            else:
                pjTree[pid] = [pjid]

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
        statusClosed[status['name']] = status['is_closed']

d = {}
with open(sys.argv[1]) as csvDataFile:
    csvReader = csv.reader(csvDataFile)
    for row in csvReader:
        if statusClosed[row[4]] and showClosed == False:
            continue
        pjid = int(row[1])
        tid = int(row[2])
        trackers[tid] = row[3]
        ratios[tid] = int(row[5])
        prios[tid] = int(row[8])
        if showColor == True:
            if statusClosed[row[4]] == True:
                status[tid] = fg(row[4], 238)
            elif row[4] == defaultTracker[trackers[tid]]:
                status[tid] = fg(row[4], 200)
            else:
                status[tid] = fg(row[4], 228)
            if ratios[tid] == 0:
                ratios[tid] = fg(row[5], 200)
            elif ratios[tid] == 100:
                ratios[tid] = fg(row[5], 48)
            else:
                ratios[tid] = fg(row[5], 228)
            if prios[tid] == 1:
                prios[tid] = fg(str(prios[tid]), 8)
            elif prios[tid] == 2:
                prios[tid] = fg(str(prios[tid]), 4)
            elif prios[tid] == 3:
                prios[tid] = fg(str(prios[tid]), 2)
            elif prios[tid] == 4:
                prios[tid] = fg(str(prios[tid]), 3)
            elif prios[tid] == 5:
                prios[tid] = fg(str(prios[tid]), 1)
            trackers[tid] = fg(trackers[tid], trackerColor[trackers[tid]])
        else:
            status[tid] = row[4]
            ratios[tid] = row[5]
        subjects[tid] = row[6]
        if not row[0]: # top level ticket
            pjTopIds[pjid].append(tid)
        else:
            pid = int(row[0])
            if pid in d:
                d[pid].append(tid)
            else:
                d[pid] = [tid]


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

# print(pjTopIds)
# print(d)

def show_ticket(tid, depth):
    rel = ""
    if str(tid) in relations.keys():
        rel = relations[str(tid)]
    print("%s%d <%s|%s|%s|%s> %s%s" % ("  "*depth, tid, trackers[tid], status[tid], ratios[tid], prios[tid], rel, subjects[tid]))
    if tid in d:
        for cid in d[tid]:
            show_ticket(cid, depth+1)

def show_project(pjid, depth):
    print("%sPJ%d %s" %("  "*depth, pjid, pjNames[pjid]))
    if showPjonly == False:
        for tid in pjTopIds[pjid]:
            show_ticket(tid, depth + 1)
    if showSubproject == True:
        for cpj in pjTree[pjid]:
            show_project(cpj, depth + 1)

if tickets:
    for tid in tickets:
        show_ticket(tid, 0)
elif projects:
    for pj in projects:
        show_project(pj, 0)
else:
    for pj in topPjs:
        show_project(pj, 0)
