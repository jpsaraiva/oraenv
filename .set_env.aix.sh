#!/bin/ksh
#######################################################################################################
#  NAME               : .set_env
#  Summary            : 
#  Usage              : .set_env..............    # Displays the menu
#                     : .set_env [DB_NAME]......  # Loads environment variable for specific database
#--------------------------------------------------------------------------
#
#--------------------------------------------------------------------------
# Revision History
#
#Revision|Date_____|By_________|_Object______________________________________
#  1.0   |20180220 | J.SARAIVA | Modified original .set_env to work with KSH on AIX
#                              | works with ksh, ksh93 features would be awesome but not available
######################################################################################################
PROGNAME=real.sh # set manually because sourced and AIX...
BASEDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
REVISION="1.0"
LASTUPDATE="2018-02-20"
IFS=

#Custom PATHs
export SQLPATH=
###

print_revision() {
	echo "${PROGNAME}: v${REVISION} (${LASTUPDATE})"
}

print_usage() {
  echo "Usage:"
  printf " %-30s # %s\n" ".set_env" "Displays the database menu and loads generic env vars"
  printf " %-30s # %s\n" ".set_env [DB_NAME]" "Loads environment variables for specific database"
  printf " %-30s # %s\n" ".set_env --all" "Displays all running databases"
  printf " %-30s # %s\n" ".set_env --user [USER_NAME]" "Displays databases running on the specified user"
  printf " %-30s # %s\n" ".set_env --help" "Displays the help menu"
  printf " %-30s # %s\n" ".set_env --version" "Displays version information"
}

print_help() {
  print_revision
  echo ""
  echo "Displays and loads Oracle Database enviroments variables"
  echo ""
  print_usage
}


print_banner() {
 if [[ ${_OVERRIDEUSER} -eq 1 ]]; then
  _USER=${_IMPERSONATE}
 else
  _USER=`whoami`
 fi
 
 if [[ ${_NOUSERVALIDATE} -eq 1 ]]; then
   _USER="all"
 fi
 
 #__________________________
 ## BANNER
 ## present DBs in /etc/oratab and define alias for each one under logged user
 #--------------------------
 clear
 echo "######################################################################"
 echo "# Defined instances on the machine with the user -> ${_USER}          "
 echo "######################################################################"
 echo "#"
 
 #get running databases
 IFS=
 RUNNING=`ps -ef | sed 's/ *$//' | grep [p]mon | awk '{print $1 " " $9 }'`
 
 ## Find and define ORATAB with its location
 if [[ -f /etc/oratab ]]; then
  export ORATAB=/etc/oratab
 else
  echo "### WARNING:    FILE oratab UNACESSIBLE OR UNEXISTANT"
 fi
 
 if [[ ! -z "$ORATAB" ]]; then
 export ORALINE="" #global var
 IFS='
'     
 ORATAB=`cat $ORATAB | egrep -v "^#|^\*" | grep -v -e '^$' | grep -v "^[^+].*\# line added by Agent" | awk '/./' | awk -F":" '{print $1 " "$2}' | sort -u`
 for LINE in $ORATAB 
 do
   _ORA_SID=`echo $LINE | awk '{print $1}' -`  #extract ORACLE_SID
   _ORA_HOME=`echo $LINE | awk '{print $2}' -`  #extract ORACLE_HOME 
   _ORA_SID_PROC_OWNER=`echo "$RUNNING" | grep "[p]mon_${_ORA_SID}$" | awk '{print $1}'`  # from running
   #check status
   if [[ ${RUNNING} == *"_${_ORA_SID}"* ]]; then
     _ORA_STATUS="RUNNING"
   else
     _ORA_STATUS="NOT RUNNING"
     _ORA_SID_PROC_OWNER=`ls -l ${_ORA_HOME}/bin/oracle | awk '{print $3}'` #this will get the owner of oracle binary and set it as database owner
   fi
   RUNNING=`echo "$RUNNING" | grep -v "[p]mon_${_ORA_SID}$"`
   #validate ownership
   if [[ ! -z ${_NOUSERVALIDATE} ]] || [[ $_ORA_SID_PROC_OWNER == $_USER ]] || [[ -z ${_ORA_SID_PROC_OWNER} ]]; then 
     # if --all parameter have been user
     # OR the current user (might be an impersonation with --user) is the owner of the instance
     # OR the database is down (no owner is determined)      
     if [[ $_ORA_SID_PROC_OWNER == $_USER ]]; then
       printf "# %9s : %-40s : %s \n" "${_ORA_SID}" "${_ORA_HOME}" "${_ORA_STATUS}" #the %<n>s correnpondent to ORACLE_HOME may vary
     else
       printf "# %9s : %-40s : %s @ %s \n" "${_ORA_SID}" "${_ORA_HOME}" "${_ORA_STATUS}" "$_ORA_SID_PROC_OWNER" #the %<n>s correnpondent to ORACLE_HOME may vary
     fi
     alias ${_ORA_SID}=". ${BASEDIR}/${PROGNAME} ${_ORA_SID}" #define alias for DB
   fi
   export ORALINE=${ORALINE}:${_ORA_SID} #save a list of SID for future validations
 done

# Databases running not in ORATAB
if [[ ! -z $RUNNING && ${_NOUSERVALIDATE} -eq 1 ]] || [[ ${RUNNING} == *"${_USER}"* ]];
then
echo "#"
echo "# Databases running not configured in ORATAB:"
for line in $RUNNING
do
  _ORA_SID=`echo $line | awk '{print $2}' - | sed 's/ora_pmon_//g'`  #extract ORACLE_SID
  _ORA_HOME="not determinated"  #extract ORACLE_HOME 
  _ORA_SID_PROC_OWNER=`echo "$RUNNING" | grep "[p]mon_${_ORA_SID}$" | awk '{print $1}'`  # from running
  if [[ ! -z ${_NOUSERVALIDATE} ]] || [[ $_ORA_SID_PROC_OWNER == $_USER ]] || [[ -z ${_ORA_SID_PROC_OWNER} ]]; then     
    if [[ $_ORA_SID_PROC_OWNER == $_USER ]]; then
      printf "# %9s : %-40s : %s \n" "${_ORA_SID}" "${_ORA_HOME}" "${_ORA_STATUS}" #the %<n>s correnpondent to ORACLE_HOME may vary
    else
      printf "# %9s : %-40s : %s @ %s \n" "${_ORA_SID}" "${_ORA_HOME}" "${_ORA_STATUS}" "$_ORA_SID_PROC_OWNER" #the %<n>s correnpondent to ORACLE_HOME may vary
    fi
    alias ${_ORA_SID}=". ${BASEDIR}/${PROGNAME} ${_ORA_SID}" #define alias for DB
  fi
done
fi

 fi
 
 if [[ `ps -ef | grep [e]magent | wc -l| bc` -ge 1 ]] ; then
   echo "#"
   echo "# Enterprise Manager Agent:"
   alias AGENT=". ${BASEDIR}/${PROGNAME} AGENT"
   echo "#        AGENT"
 fi
 
 echo "#"
 echo "######################################################################"
 echo "# To define Oracle environment type instance name (check alias on OS)#"
 echo "######################################################################"
 echo ""
}

set_sp() {
 if [[ ${OSID} == *"+ASM"* ]]; then
    ${OHOME}/bin/sqlplus / as sysasm
 else
    ${OHOME}/bin/sqlplus / as sysdba
 fi
}

set_alias() {
 export OSID=$ORACLE_SID
 export OBASE=$ORACLE_BASE
 export OHOME=$ORACLE_HOME
 export ODIAG=$DIAG_DEST
 export GHOME=$GRID_HOME
 # DB
 alias         sp=set_sp # sp will choose between sysasm or sysdba according to OSID
 alias spc='sqlplus -L -S / as sysdba @$1'
 alias      cdora='cd ${OHOME}'
 alias        dbs='cd ${OHOME}/dbs'
 alias        net='cd ${OHOME}/network/admin'
 alias        adm='cd ${ODIAG}/diag'
 alias      bdump='cd ${ODIAG}/diag/`[[ ${OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${OSID%[0-3]} |tr '[:upper:]' '[:lower:]'`/${OSID}/trace'
 alias      cdump='cd ${ODIAG}/diag/`[[ ${OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${OSID%[0-3]} |tr '[:upper:]' '[:lower:]'`/${OSID}/cdump'
 alias      udump='cd ${ODIAG}/diag/`[[ ${OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${OSID%[0-3]} |tr '[:upper:]' '[:lower:]'`/${OSID}/trace'
 alias      alert='vi ${ODIAG}/diag/`[[ ${OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${OSID%[0-3]} |tr '[:upper:]' '[:lower:]'`/${OSID}/trace/alert_${OSID}.log'
 alias tail_alert='tail -50f ${ODIAG}/diag/`[[ ${OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${OSID%[0-3]} |tr '[:upper:]' '[:lower:]'`/${OSID}/trace/alert_${OSID}.log'
 # OSID%[0-3] in tr is a fix to avoid since instances terminated in a number like ORA7 to be transformed to ora instead of ora7, better validation should be made 
  
 # SO
 alias   ll="ls -l"     #Simple ll
 alias   pp="ps -ef | grep [p]mon_ | sort -k8"
 alias   pl="ps -ef | grep [t]nslsnr | sort -k8"
 alias   po="ps -ef | grep [o]id"
 alias pall="echo DATABASES:; ps -ef | grep [p]mon_ | sort -k8; echo; echo LISTENERS:;ps -ef | grep [t]nslsnr | sort -k8; echo; echo AGENTS:; ps -ef | grep -i [d]bsnmp; ps -ef | grep -i [e]magent | grep -v java; echo; echo DATA GATHERERS:; ps -ef | grep -i [v]pp; echo"
 alias menu=". ${BASEDIR}/${PROGNAME} ${_PARAMS}" # keep the same parameters as the initial call
}

set_editor() {
 ## Define interface VI na shell
 if [[ `echo ${SHELL} | grep -c "bash"` -eq 0 ]]; then
  set -o vi
 fi
 set +o nounset             # exit when your script tries to use undeclared variables
 #export TMP=/dev/shm       # use ram instead of fs #JPS# commented out
 #export TMPDIR=/dev/shm    # use ram instead of fs #JPS# commented out
 export EDITOR=vi
 export PS1=`whoami`@`hostname`:'${ORACLE_SID}'['${PWD}']'$ '
 export PS2='$ '
 export ORACLE_TERM=vt220
 export NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'
}

set_env() {
 # validate existance in ORALINE
 _MY_SID=$1
 if [[ ${ORALINE} != *"${_MY_SID}"* ]]; then 
   echo " ${_MY_SID} not found! Confirm that it exists and oratab a reload using the command: menu"
   return
 fi
 # use . oraenv
 export ORAENV_ASK=NO
 export ORACLE_SID=${_MY_SID}
 . oraenv > /dev/null # hide message "The Oracle base for ORACLE_HOME=XXX is YYYY"
 unset ORAENV_ASK # to allow to use . oraenv directly
 unset AGENT_HOME
 unset EMSTATE
 unset GRID_HOME
 export TNS_ADMIN=$ORACLE_HOME/network/admin
 [[ ${_MY_SID} == *"+ASM"* ]] && export GRID_HOME=$ORACLE_HOME
 # export NLS_LANG; format: NLS_LANG=LANGUAGE_TERRITORY.CHARACTERSET
 get_db_information ${_MY_SID}
 set_nls_lang
 set_diag_dest
 set_alias # moved to here on AIX due to missing parameter indirection on ksh
}

set_agent_env() { 
 export ORACLE_SID=EMAGENT
 export ORACLE_HOME=`ps -ef | grep -i "emwd.pl agent" | grep -v grep | awk '{print $9}' | head -1 | sed -s 's/\/bin\/emwd.pl//'` # Only one agent per host is supported
 export PATH=$ORACLE_HOME/bin:$PATH
 export AGENT_HOME=$ORACLE_HOME
 export EMSTATE=`ps -ef | grep -i "emagent.nohup" | grep -v grep | awk '{print $11}' | sed -s 's/agent_inst\/.*/agent_inst/' `
 export OMS_HOME=`ps -ef | grep -v grep| egrep --color 'EMGC_ADMINSERVER|EMGC_OMS.'|sed -nr 's/.*-DORACLE_HOME=([^ ]+).*/\1/p'`
 export GRID_HOME=$OMS_HOME
}

get_db_information(){
	_MY_SID=$1
	if [[ ${_MY_SID} == *"+ASM"* ]]; then # if ASM unset NLS_LANG
		unset NLS_LANG
		return
	fi
	_DB_INFO=`sqlplus -S -L / as sysdba <<EOF
	set echo off ver off feedb off head off pages 0	
	WHENEVER SQLERROR CONTINUE NONE;
	select '_NLS_LANG='||a.value||'_'||b.value||'.'||c.value as nls_lang from nls_database_parameters a, nls_database_parameters b, nls_database_parameters c where 1=1 and a.parameter = 'NLS_LANGUAGE' and b.parameter = 'NLS_TERRITORY' and c.parameter = 'NLS_CHARACTERSET';
	select '_DIAGNOSTIC_DEST='||p.value diagnostic_dest from v\\$parameter p where p.name='diagnostic_dest';
	exit;
EOF`
	_NLS_LANG=`echo ${_DB_INFO} | tr " " "\n" | grep "^_NLS_LANG" | awk -F= '{print $2}'`
	_DIAGNOSTIC_DEST=`echo ${_DB_INFO} | tr " " "\n" | grep "^_DIAGNOSTIC_DEST" | awk -F= '{print $2}'`
}

# NLS_LANG can only be retrieved from the database
set_nls_lang(){
	if [[ -z ${_NLS_LANG} ]]; then
		unset NLS_LANG
	else
		export NLS_LANG=${_NLS_LANG}
	fi	
}

# DIAG_DEST is set according to database information
# if unavailable we will assume it is ORACLE_BASE
set_diag_dest(){
	if [[ -z ${_DIAGNOSTIC_DEST} ]]; then
		export DIAG_DEST=${!OBASE}
	else
		export DIAG_DEST=${_DIAGNOSTIC_DEST}
	fi
}


init_set_env() {
 print_banner
 set_editor
}

#main(int argc, char *argv[]) #JPS# Start here
_PARAMS=$@

if [[ $# -eq 0 ]]; then
  init_set_env
else
	case $1 in
	 AGENT) 
      set_agent_env
      ;;
   --all|-A|-a)
      _NOUSERVALIDATE=1
      init_set_env
      unset _NOUSERVALIDATE 
      ;;
   --user|-U|-u)
     _OVERRIDEUSER=1
     _IMPERSONATE=$2
     init_set_env
     unset _OVERRIDEUSER 
     unset _IMPERSONATE 
     #shift #JPS# necessary if multiple parameters are allowed in the future
     ;;
   --help|-h)
      print_help
      ;;
   --version|-V|-v)
      print_revision 
      ;;
    *) 
     set_env $1     
     ;;
	esac
fi