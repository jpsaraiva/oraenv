#!/bin/bash 
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
#  1.0   |         |           | Creation
#  2.0   |         | M.ALMEIDA | 
#  3.1   |20161020 | J.SARAIVA | Complete overhaul (only for Linux):
#                              |  Banner no longer lags, just one ps is done for all databases
#                              |  Banner text reformated
#                              |  .profile files no longer necessary, alias are created dinamically
#                              |  Several parameters introduced to enable using the script as any user
#                              |  Alias available either with script usage or through oraenv
#                              |  EM Agent environment variables load automaticaly (only 1)
#                              |  export NLS_LANG is not implemented due to being database specific (no longer true, check 3.2)
#  3.2   |20161114 | J.SARAIVA | Filter added to ORATAB to exclude # line added by Agent
#                              | Added fucntion to load NLS_LANG by connecting to the database itself, ASM exception
#  3.2.1 |20161115 | J.SARAIVA | Alias sp will choose between sysasm or sysdba according to OSID
#  3.2.2 |20161121 | N.ALVES   | Replaced sqlplus -SL with sqlplus -S -L due to problems connections to databases 12c
#  3.3   |20161122 | J.SARAIVA | get_db_information created to return general information from the database 
#                              |  functions set_nls_lang and set_diag_dest will read information saved in get_db_information
#                              | replaced ' with " on AGENT alias
#  3.3.1 |20161214 | J.SARAIVA | Unset NLS_LANG when changing to ASM instance added
#                              | Variable from get_db_information are now empty if there is an error, preventing problems on standby database
#  3.3.2 |20170123 | J.SARAIVA | Added exclusion of blank lines in oratab
#  3.3.3 |20170303 | J.SARAIVA | Removed ASM filter in oratab to prevent problems with single instance and 12c env -- may not be compatible with current oratab config!!!!!
#  3.3.4 |20170303 | M.ALMEIDA | Modified agent load environment settings
#  3.3.5 |20170303 | J.SARAIVA | Added spc alias to execute sql file
#  3.3.6 |20170601 | J.SARAIVA | Database ownership is now validated against $ORACLE_HOME/bin/oracle ownership if database is down
#                              | Alias are only set for database if it is owned by the current user, or -u or -a is used
#                              | Proper alias are now set when ASM is used
######################################################################################################
SOURCE="${BASH_SOURCE[0]}" #JPS# the script is sourced so this have to be used instead of $0 below
PROGNAME=`basename ${SOURCE}` 
BASEDIR="$( dirname "$SOURCE" )"
REVISION="3.3"
LASTUPDATE="2017-06-01"

export OSID=ORACLE_SID
export OBASE=ORACLE_BASE
export OHOME=ORACLE_HOME
export ODIAG=DIAG_DEST
export GHOME=GRID_HOME

#Custom PATHs
export SQLPATH=/products/backup/oracle/dba/sql
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
 #__________________________
 ## BANNER
 ## present DBs in /etc/oratab and define alias for each one under logged user
 #--------------------------
 clear
 echo "######################################################################"
 echo "# Defined instances on the machine with the user -> ${_USER}          "
 echo "######################################################################"
 echo "#"
 ## Find and define ORATAB with its location
 if [[ -f /etc/oratab ]]; then
  export ORATAB=/etc/oratab
 else
  echo "### WARNING:    FILE oratab UNACESSIBLE OR UNEXISTANT"
 fi
 
 if [[ ! -z "$ORATAB" ]]; then
 
 export ORALINE="" #global var
 
 RUNNING=`ps -ef | sed 's/ *$//' | grep [p]mon | awk '{print $1 " " $8 }'`
 #TABLINE=`cat /etc/oratab | grep -v "^#" | grep "\`grep -oP "\+ASM\K(\d)(?=.*)" $ORATAB\`:\/" | awk '/./' | awk -F":" '{print $1":"$2}' | sort -u`
  
 while read LINE
 do
    case $LINE in
         \#*) ;;        #ignores comment-line in oratab
         *)
           _ORA_SID=`echo $LINE | awk '{print $1}' -`  #extract ORACLE_SID
           _ORA_HOME=`echo $LINE | awk '{print $2}' -`  #extract ORACLE_HOME
           _ORA_SID_PROC_OWNER=`grep "[p]mon_${_ORA_SID}$" <<< "$RUNNING" | awk '{print $1}'`  # from running
           #check status
           if [[ ${RUNNING} == *"_${_ORA_SID}"* ]]; then
             _ORA_STATUS="RUNNING"
           else
             _ORA_STATUS="NOT RUNNING"
			 _ORA_SID_PROC_OWNER=`stat -c '%U' ${_ORA_HOME}/bin/oracle` #this will get the owner of oracle binary and set it as database owner
           fi
           #validate ownership
           if [[ ! -z ${_NOUSERVALIDATE} ]] || [[ $_ORA_SID_PROC_OWNER == $_USER ]] || [[ -z ${_ORA_SID_PROC_OWNER} ]]; then 
             # if --all parameter have been user
             # OR the current user (might be an impersonation with --user) is the owner of the instance
             # OR the database is down (no owner is determined)      
             printf "# %9s : %-40s : %s \n" "${_ORA_SID}" "${_ORA_HOME}" "${_ORA_STATUS}" #the %<n>s correnpondent to ORACLE_HOME may vary
			 alias ${_ORA_SID}=". ${BASEDIR}/${PROGNAME} ${_ORA_SID}" #define alias for DB
           fi
           export ORALINE=${ORALINE}:${_ORA_SID} #save a list of SID for future validations
           ;;
    esac
 done < <(cat $ORATAB | grep -v "^#" | grep -v -e '^$' | grep -v "^[^+].*\# line added by Agent" | awk '/./' | awk -F":" '{print $1 " "$2}' | sort -u )
 # REMOVED: it will only print instances with the same instance number as the ASM instance on the oratab
 # REMOVED: head -1 above will prevent double entries of +ASM to mess with the list
 # "# line added by Agent" added to prevent db_name that end with a number to be consfused with instance_name, excluding the ASM instance (starts with +)
 # remove blank lines
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
 if [[ ${!OSID} == *"+ASM"* ]]; then
    ${!OHOME}/bin/sqlplus / as sysasm
 else
    ${!OHOME}/bin/sqlplus / as sysdba
 fi
}

set_alias() {
 # DB
 alias         sp=set_sp # sp will choose between sysasm or sysdba according to OSID
 alias spc='sqlplus -L -S / as sysdba @$1'
 alias      cdora='cd ${!OHOME}'
 alias        dbs='cd ${!OHOME}/dbs'
 alias        net='cd ${!OHOME}/network/admin'
 alias        adm='cd ${!ODIAG}/diag'
 alias      bdump='cd ${!ODIAG}/diag/`[[ ${!OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${!OSID%[0-9]} |tr '[:upper:]' '[:lower:]'`/${!OSID}/trace'
 alias      cdump='cd ${!ODIAG}/diag/`[[ ${!OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${!OSID%[0-9]} |tr '[:upper:]' '[:lower:]'`/${!OSID}/cdump'
 alias      udump='cd ${!ODIAG}/diag/`[[ ${!OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${!OSID%[0-9]} |tr '[:upper:]' '[:lower:]'`/${!OSID}/trace'
 alias      alert='vi ${!ODIAG}/diag/`[[ ${!OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${!OSID%[0-9]} |tr '[:upper:]' '[:lower:]'`/${!OSID}/trace/alert_${!OSID}.log'
 alias tail_alert='tail -50f ${!ODIAG}/diag/`[[ ${!OSID} == *"+ASM"* ]] && echo "asm" || echo "rdbms"`/`echo ${!OSID%[0-9]} |tr '[:upper:]' '[:lower:]'`/${!OSID}/trace/alert_${!OSID}.log'
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
 set_alias # this will work either if you call this script with ORACLE_SID or use . oraenv directly
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
