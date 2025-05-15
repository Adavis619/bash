# A script is required to complete the steps below.
# Usage should be something like: asg_deIdent.sh <SourceServer> <IntermediateServer> <DestinationServer> <PatientRecord>

# Required argument variables using the examples from the steps below:
SourceServer=vfenc1
IntermediateServer=comsupc
DestinationServer=asgcore1
PatientRecord=vol8/p83887228

# Note: The intermediate server is typically where the user would be running the script from. The user should know which record they want to use already.

# 1. Source Server: Identify record from a Source Server and tar it up. In this example, vfenc1 is the Source Server.
# Note: The "D" command below is used to locate and identify a patient record.
# Note: The example Patient Record below is contained in vol8/p83887228.
# Note: The name for T83887228.z was derived from vol8/p83887228
[anthonyd@comsupc]:/homes/support/anthonyd> ssh vfenc1
[anthonyd@vfenc1]:/home/anthonyd> D real 
vol8/p83887228     83887228 TEST-H   Real, Patient              000-00-9570 
# 1.1 tar up the desired record
[anthonyd@vfenc1]:/home/anthonyd> sd 
[anthonyd@vfenc1]:/vfenc/vfenc/run> .dosu tar -czvf /usr/tmp/T83887228.z vol8/p83887228
[anthonyd@vfenc1]:/vfenc/vfenc/run> exit

# 2. Transfer the tar ball to the Intermediate Server. In this example, the intermediate server is comsupc.
[anthonyd@comsupc]:/homes/support/anthonyd> scp vfenc1:/usr/tmp/T83887228.z . 
[anthonyd@comsupc]:/homes/support/anthonyd> scp T83887228.z asgcore1:/usr/tmp 

# 3. Destination Server: Untar and de-identify. In this example, the Destination Server is asgcore1. The remaining steps are all performed on the Destination Server.
# 3.1. First check if the record already exists on the destination server. 
[anthonyd@comsupc]:/homes/support/anthonyd> ssh asgcore1
[anthonyd@asgcore1]:/san/san/run> sd
[anthonyd@asgcore1]:/san/san/run> D | grep 167772263 
[anthonyd@asgcore1]:/san/san/run> .dosu ccarchlist | grep 167772263 

# 3.2. Change the permission and clear out previously processed records.
[anthonyd@asgcore1]:/home/anthonyd> cd /usr/tmp 
[anthonyd@asgcore1]:/usr/tmp> chmod 777 T83887228.z 

# 3.3. With the following commands, user might get “mkdir: cannot create directory '/usr/tmp/xidpat': File exists” error, which is OK and can be ignored. 
.dosu mkdir /usr/tmp/xidpat 
.dosu chmod 777 /usr/tmp/xidpat 
chmod 777 /usr/tmp/T*.z 

# 3.4. Set up the variables(TFILE and TVOL) and perform untar and de-identification. Make sure you update the variables to match the current patient record.
cd /usr/tmp
TFILE=T83887228.z 
TVOL=vol8/p83887228      
chmod 777 $TFILE 
ls -l $TFILE 
.dosu tar xvfz $TFILE 
.dosu deIdent -p  /usr/tmp/$TVOL -c $CCSYSDIR/deIdent.rcf -s $CCSYSDIR/deIdent.staff  -l xidlog -d debug 
cd /usr/tmp/xidpat 
.dosu tar cvfz /usr/tmp/$TFILE $TVOL 
ls -l /usr/tmp/$TFILE 
.dosu rm -r /usr/tmp/xidpat/vol* 
.dosu rm -r /usr/tmp/$TVOL 
.dosu rm /usr/tmp/xidpat/vol* 

# 3.5. Add de-identified record. Set up the variable (PATID) and run. PATID is the number after vol?/p. In this example PATID is 83887228 from vol8/p83887228 
sd 
.dosu tar xvfz /usr/tmp/$TFILE 
.dosu addpat $TVOL 
PATID=83887228 CAMPUS=$SITE .dosu cql -S -iwritecampus.scm 
D $TVOL 

# 3.6 Update the name of the de-identified record.
# 3.6.1. Ensure the variable is correctly set with the patient record we want.
[anthonyd@asgcore1]:/san/san/run> D $TVOL
vol8/p83887228     83887228 NOBED    XidPat 001                 03967283161      000000 
# 3.6.2. Then run command to update the name in the record.The user will continue on their own from here. 
[anthonyd@asgcore1]:/san/san/run> .dosu changeAdmitDbitem -n 
