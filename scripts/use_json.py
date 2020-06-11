import sys
import json
import os
import re

showClosed = False
showColor= False
showSubproject = False
projects = None
tickets = None
grouping = False
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

subjects = {}
trackers = {}
status = {}
ratios = {}
updateds = {}
closeds = {}
pjs = {}

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

with open(sys.argv[1]) as json_file:
    data = json.load(json_file)
    for p in data['issues']:
        tid = p['id']
        pjid = p['project']['id']
        if not pjid in pjIds.keys():
            pjIds[pjid] = []
        if not pjid in pjNames.keys():
            pjNames[pjid] = p['project']['name']
        if p['closed_on'] and showClosed == False:
            continue
        if projects and not pjid in pjIncluded:
            continue
        pjIds[pjid].append(tid)
        globalIds.append(tid)
        subjects[tid] = p['subject']
        trackers[tid] = p['tracker']['name']
        closeds[tid] = p['closed_on']
        ratios[tid] = int(p['done_ratio'])
        if showColor == True:
            if closeds[tid]:
                status[tid] = fg(p['status']['name'], 243)
            else:
                status[tid] = fg(p['status']['name'], 32)
            if ratios[tid] == 0:
                ratios[tid] = fg(str(ratios[tid]), 200)
            elif ratios[tid] == 100:
                ratios[tid] = fg(str(ratios[tid]), 48)
            else:
                ratios[tid] = fg(str(ratios[tid]), 228)
        else:
            status[tid] = p['status']['name']
            ratios[tid] = str(ratios[tid])
        updateds[tid] = p['updated_on']
        pjs[tid] = pjid

def take_updated_on(tid):
    return updateds[tid]

def show_project(pj):
    print("PJ%d\t%s" % (pj, pjNames[pj]))
    sorted_tids = sorted(pjIds[pj], key=take_updated_on)
    for tid in sorted_tids:
        show_ticket(tid, False)
    print("")

def show_ticket(tid, showPj):
    if showPj:
        print("%d\t%s\tPJ%d\t<%s|%s|%s>\t%s" % (tid, updateds[tid], pjs[tid], trackers[tid], status[tid], ratios[tid],  subjects[tid]))
    else:
        print("%d\t%s\t<%s|%s|%s>\t%s" % (tid, updateds[tid], trackers[tid], status[tid], ratios[tid],  subjects[tid]))

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
