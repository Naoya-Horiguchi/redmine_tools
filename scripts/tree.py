import sys
import csv
import os
import re

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

showClosed = False
showColor= False
showSubproject = False
showPjonly = False
projects = None
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

trackers = {}
status = {}
ratios = {}
subjects = {}
closeds = {}

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

d = {}
with open(sys.argv[1]) as csvDataFile:
    csvReader = csv.reader(csvDataFile)
    for row in csvReader:
        if row[7] and showClosed == False:
            continue
        pjid = int(row[1])
        tid = int(row[2])
        trackers[tid] = row[3]
        ratios[tid] = int(row[5])
        if showColor == True:
            if row[7]:
                status[tid] = fg(row[4], 243)
            else:
                status[tid] = fg(row[4], 32)
            if ratios[tid] == 0:
                ratios[tid] = fg(row[5], 200)
            elif ratios[tid] == 100:
                ratios[tid] = fg(row[5], 48)
            else:
                ratios[tid] = fg(row[5], 228)
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

# print(pjTopIds)
# print(d)

def show_ticket(tid, depth):
    print("%s%d <%s|%s|%s> %s" % ("  "*depth, tid, trackers[tid], status[tid], ratios[tid], subjects[tid]))
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

if projects:
    for pj in projects:
        show_project(pj, 0)
else:
    for pj in topPjs:
        show_project(pj, 0)

# with open(sys.argv[1]) as csvDataFile:
#     csvReader = csv.reader(csvDataFile)
#     for row in csvReader:
#         if row[7]:
#             continue
#         pjid = int(row[1])
#         tid = int(row[2])
#         trackers[tid] = row[3]
#         status[tid] = row[4]
#         ratios[tid] = int(row[5])
#         subjects[tid] = row[6]
#         pjTopIds[pjid].append(tid)

# d = {}
# with open(sys.argv[2]) as csvDataFile:
#     csvReader = csv.reader(csvDataFile)
#     for row in csvReader:
#         if row[7]:
#             continue
#         pjid = int(row[1])
#         tid = int(row[2])
#         pid = int(row[0])
#         trackers[tid] = row[3]
#         status[tid] = row[4]
#         ratios[tid] = int(row[5])
#         subjects[tid] = row[6]
#         pjTopIds[pjid].append(tid)
#         if pid in d:
#             d[pid].append(tid)
#         else:
#             d[pid] = [tid]
