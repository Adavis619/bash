# this script should be run from my local host using:
for i in `cat /$CCSYSDIR/EHR/serverlist/serverlist_va1`; do echo $i; ssh -n $i 'asg_listcheck.sh'; done
# The list files to check will be in this directory on every host checked:
$CCRUN/conf/webess/screens
# it will check list.fs* and list.default* files for correct numerical order of lines within them.
# Ignore any files that end in ALPHA-*, PGOLD-*, any files with more than two periods - like this one: "list.default.5ATELE.20250310_125237.anthonyd". Also ignore files that end with a "~".

# The file contents will typically look like list.fs.SORTTEST below.
# the script should output a message indicating the filename and if the lines are either out of numerical order and/or not consecutively numbered properly.
# lines that are commented out can be ignored.
# Write output messages to /usr/tmp/list_file_report

$CCRUN/conf/webess/screens > cat list.fs.SORTTEST
1[]s[][][][][][][][][]button[][]UINotes []screens/getconf[]{":screenconf":"uinotes.conf"}[]CPOE2[][][][]hidesingle
2[]s[][][][][][][][]default[]button[][]Radiology Reports[]screens/getconf[]{":screenconf":"radiology.conf"}[][][][][]hidesingle_not_parent
3[]s[][][][][][][][]default[]button[][]Microbiology[]screens/getconf[]{":screenconf":"microbiology.conf"}[][][][][]hidesingle_not_parent
4[]s[][][][][][][][]default[]button[][]Pathology[]screens/getconf[]{":screenconf":"pathology.conf"}[][][][][]hidesingle_not_parent
5[]s[][][][][][][][][]button[][]Sepsis-X[]screens/getconf[]{":screenconf":"Sepsis_Summary.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "ssprnn"}[][][][]
6[]s[][][][][][][][][]button[][]Waveform Results Viewer[]screens/getconf[]{":screenconf":"pvc_viewer.conf"}[]Waveform Results Viewer[][][][]hidesingle
7[]s[][][][][][][][][]button[][]QTc Clock[]screens/getconf[]{":screenconf":"qtc_clock.conf"}[]QTc Clock[][][][]hidesingle
8[]s[][][][][][][][][]button[][]QTc Dist[]screens/getconf[]{":screenconf":"qtc_dist.conf"}[]QTc Dist[][][][]hidesingle
9[]s[][][][][][][][][]button[][]WaveSQI Viewer[]screens/getconf[]{":screenconf":"ksqi_viewer.conf"}[]WaveSQI Viewer[][][][]hidesingle
10[]s[][][][][][][][][]button[][]ARDS[]screens/getconf[]{":screenconf":"ards.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "ards_new"}[][][][]
11[]s[][][][][][][][][]button[][]Single ARDS[]screens/getconf[]{":screenconf":"vent_ards_single.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "ards_new"}[][][][]
12[]s[][][][][][][][][]button[][]Vent ARDS[]screens/getconf[]{":screenconf":"vent_ards.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "ards_new"}[][][][]
13[]s[][][][][][][][][]button[][]Vent[]screens/getconf[]{":screenconf":"Vent_Summary.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "vent"}[][][][]
14[]s[][][][][][][][][]button[][]General[]screens/getconf[]{":screenconf":"24_Summary.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "applicationName":"IPS"}[][][][]
15[]s[][][][][][][][][]button[][]Critical Care Rounding[]screens/getconf[]{":screenconf":"DOD_CritCareRound.conf"}[]SummaryScreen[][][][]hidesingle
16[]s[][][][][][][][][]button[][]Lab Review[]screens/getconf[]{":screenconf":"LabReviewSummary.conf"}[]SummaryScreen[][][][]hidesingle
17[]s[][][][][][][][][]button[][]Nutrition[]screens/getconf[]{":screenconf":"Nutrition.conf"}[]SummaryScreen[][][][]hidesingle
18[]s[][][][][][][][][]button[][]Renal[]screens/getconf[]{":screenconf":"Renal_Summary.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "renal"}[][][][]
19[]s[][][][][][][][][]button[][]Cardiac[]screens/getconf[]{":screenconf":"TEST_TropSummary.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "troponin"}[][][][]
20[]s[][][][][][][][][]button[][]Coag[]screens/getconf[]{":screenconf":"Coag.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "coag"}[][][][]
21[]s[][][][][][][][][]button[][]Infection[]screens/getconf[]{":screenconf":"InfectSummary.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "infect"}[][][][]
22[]s[][][][][][][][][]button[][]Resp[]screens/getconf[]{":screenconf":"RespSummaryX.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "resp"}[][][][]
23[]s[][][][][][][][][]button[][]SOFA[]screens/getconf[]{":screenconf":"sofa.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "totalsofa"}[][][][]
24[]s[][][][][][][][][]button[][]Covid[]screens/getconf[]{":screenconf":"covid.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "totalsofa"}[][][][]
24[]s[][][][][][][][][]button[][]TEST LINE 3[]screens/getconf[]{":screenconf":"covid.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "totalsofa"}[][][][]
39[]s[][][][][][][][][]button[][]TEST LINE 4[]screens/getconf[]{":screenconf":"sofa.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "totalsofa"}[][][][]
44[]s[][][][][][][][][]button[][]TEST LINE[]screens/getconf[]{":screenconf":"TEST_TropSummary.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "ewdrule": "troponin"}[][][][]
54[]s[][][][][][][][][]button[][]TEST LINE 2[]screens/getconf[]{":screenconf":"LabReviewSummary.conf"}[]SummaryScreen[][][][]hidesingle
#2[]s[][][][][][][][][]button[][]Drug Vitals[]screens/getconf[]{":screenconf":"IvVitals_Summary.conf"}[]SummaryScreen[][][][]hidesingle
#3[]s[][][][][][][][][]button[][]Clinical Summary[]screens/getconf[]{":screenconf":"24_Summary.conf"}[]SummaryScreen[][][][]{"hidesingle": true, "applicationName":"IPS"}[][][][]
#17[]s[][][][][][][][][]button[][]SOFA Table[]screens/getconf[]{":screenconf":"rtr_sofa.conf"}[][][][][]{"hidesingle": true}[][][][][]
#8[]s[][][][][][][][][]button[][]Drug Vitals[]screens/getconf[]{":screenconf":"IvVitals_Summary.conf"}[]SummaryScreen[][][][]hidesingle
#13[]s[][][][][][][][][]button[][]TEST[]screens/getconf[]{":screenconf":"Tasklist_Summary.conf"}[]SummaryScreen[][][][]hidesingle
