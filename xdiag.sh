#!/bin/bash

#############################################################################################################################
# Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# https://creativecommons.org/licenses/by-sa/4.0/legalcode
#############################################################################################################################

PGM=`basename "$0"`

usage ()
{
    printf "xPaaS Diagnostic Utilities\n\n"
    printf "Must be logged into an Openshift environment to use this script.\n"
    printf "Login command example:\n"
    printf "oc login https://some-openshift-master:8443/\n\n"
    printf "Usage:\n"
    printf "  %s [-dh] TASKS -p POD [-o DIRECTORY]\n\n" "$PGM"
    printf "Examples:\n"
    printf "  Retrieve a copy of the JBoss standalone-openshift.xml from a running xPaaS container and save the file in the current directory.\n"
    printf "  $ %s -p some-pod-name -c\n" "$PGM"
    printf "\n"
    printf "  Retrieve the Dockerfiles from a running xPaaS container.\n"
    printf "  $ %s -p some-pod-name -f\n" "$PGM"
    printf "\n"
    printf "  Get a JBoss JDR report from a running xPaaS container and save the file in the current directory.\n"
    printf "  $ %s -p some-pod-name -j\n" "$PGM"
    printf "\n"
    printf "  Get a Java heap file from a running xPaaS container and save the file in the /tmp/foo directory.  The output directory must exist.\n"
    printf "  $ %s -p some-pod-name -m -o /tmp/foo\n" "$PGM"
    printf "\n"
    printf "  Get a Java heap file and a Java thread dump from a running xPaaS container and save the files in the current directory.\n"
    printf "  $ %s -p some-pod-name -mt\n" "$PGM"
    printf "\n"
    printf "  Get a JBoss JDR report, Java heap file and a Java thread dump from a running xPaaS container and save the files in the current directory.\n"
    printf "  $ %s -p some-pod-name -jmt\n" "$PGM"
    printf "\n\n"
    printf "Options:\n"
    printf "  -o : Ouput directory.  If omitted, the current directory is used\n"
    printf "  -p : Pod name\n"
    printf "  -d : Leave generated files in pod container.  Generated files are deleted by default\n"
    printf "  -h : help\n"
    printf "\n\n"
    printf "Tasks:\n"
    printf "  -c : Retrieve a copy of the JBoss standalone-openshift.xml from a running xPaaS container\n"
    printf "  -f : Retrieve the Dockerfiles from a running xPaaS container\n"
    printf "  -j : Get a JBoss JDR report from a running xPaaS container\n"
    printf "  -m : Get a Java heap file from a running xPaaS container\n"
    printf "  -t : Get a Java thread dump from a running xPaaS container\n"
    exit 0
}

AWK=`type -p awk`
CUT=`type -p cut`
MKTEMP=`type -p mktemp`

# See if the Openshift client is in the path
RC=
RC=`type -p oc`
if [ -z "$RC" ]
then
    printf "The Openshift client does not appear in PATH.  Please install the client and ensure it is in the PATH environment variable.\n"
    printf "More information about the Openshift client can be found here - https://docs.openshift.org/latest/cli_reference/get_started_cli.html\n\n"
    exit 1
fi

GETCONFIG=0
GETDOCKERFILES=0
JDR=0
HEAPDUMP=0
THREADDUMP=0
PODNAME=
OUTDIR=`pwd`
NOOP=
NOCLEAN=
POD_ENV=
X_JAVA_HOME=
X_JBOSS_HOME=
TMPFILENAME=


loggedIn ()
{
  RC=`oc whoami`
  if echo "$RC" | grep -q "^Error"
  then
       return 0
  else
      return 1
  fi
}

getTempFileName ()
{
    if [ -z "$TMPFILENAME" ]
    then
        TMPFILENAME=$(mktemp -u "$(date +"%Y%m%d")_XXXXXX")
    fi
    echo "$TMPFILENAME"
}

validatePodName ()
{
    POD=$1
    POD_DETAILS=`oc describe pod "$POD" | head -1`
    if echo "$POD_DETAILS" | grep -q "Name:"
    then
         return 0
    else
        return 1
    fi
}

getPodEnv ()
{
    POD=$1
    if [ -z "$POD_ENV" ]
    then
        POD_ENV=`oc exec "$POD" env`
    fi
}

getEnvVar ()
{
    POD=$1
    ENVVAR=$2
    getPodEnv "$POD"
    echo "$POD_ENV" | grep -m 1 ""$ENVVAR"=" | $CUT -d"=" -f2
}

getJbossLoc ()
{
    POD=$1
    if [ -z "$X_JBOSS_HOME" ]
    then
        X_JBOSS_HOME="$(getEnvVar "$POD" "JBOSS_HOME")"
    fi
}

##############################################################
# From a host that has the Openshift oc client installed, this
# command will create a JDR report archive in a running container
# and then copy the file to the local host
##############################################################
xjdr ()
{
    POD=$1
    TARGETDIR=$2
    getJbossLoc "$POD"
    if [ -z "$X_JBOSS_HOME" ]
    then
        printf "\n\nContainer %s does not have JBOSS_HOME set.  Unable to gather JDR report.\n\n" "$POD"
    else
        RC=`oc exec "$POD" "$X_JBOSS_HOME"/bin/jdr.sh`
        OUTFILE=$(echo "$RC" | grep "JDR location" | $AWK '{print $3}')
        oc rsync "$POD":"$OUTFILE" "$TARGETDIR"

        # JDR doesn't support output redirection.  Files are created in $HOME for the jboss user (/home/jboss)
        if [ -z $NOCLEAN ]
        then
            oc exec $POD rm "$OUTFILE"
        fi
    fi

}


##############################################################
# Gather a HEAP dump from a running container
##############################################################
xheap ()
{
    POD=$1
    TARGETDIR=$2
    X_HOME="$(getEnvVar "$POD" "HOME")"
    OUTFILE="$X_HOME/$POD-$(getTempFileName)-heap.hprof"
    PID=$(oc exec $POD ps aux | grep java | $AWK '{print $2}')
    oc exec $POD -- jmap -J-d64 -dump:format=b,file="$OUTFILE" "$PID"
    oc rsync $POD:"$OUTFILE" $TARGETDIR
    if [ -z $NOCLEAN ]
    then
        oc exec $POD rm "$OUTFILE"
    fi
}


##############################################################
# Gather a Thread dump[s] from a running container
##############################################################
xthreads ()
{
    POD=$1
    TARGETDIR=$2
    X_HOME="$(getEnvVar "$POD" "HOME")"
    OUTFILE="$X_HOME/$POD-$(getTempFileName)-jstack.out"
    PID=$(oc exec $POD ps aux | grep java | $AWK '{print $2}')
    oc exec $POD -- bash -c "for x in {1..10}; do jstack -l $PID >> "$OUTFILE"; sleep 2; done"
    oc rsync $POD:"$OUTFILE" $TARGETDIR
    if [ -z $NOCLEAN ]
    then
        oc exec $POD rm "$OUTFILE"
    fi
}


##############################################################
# Retrieve a copy of the standalone-openshift.xml config file
# from a running container
##############################################################
xstandalone-config ()
{
    POD=$1
    TARGETDIR=$2
    getJbossLoc "$POD"
    if [ -z "$X_JBOSS_HOME" ]
    then
        printf "\n\nContainer %s does not have JBOSS_HOME set.  Unable to retrieve config file.\n\n" "$POD"
    else
        X_CONFIG_XML="$X_JBOSS_HOME"/standalone/configuration/standalone-openshift.xml
        oc rsync "$POD":"$X_CONFIG_XML" "$TARGETDIR"
    fi

}


##############################################################
# Retrieve dockerfiles from a running container
##############################################################
xdockerfiles ()
{
    POD=$1
    TARGETDIR=$2
    OUTDIR="$TARGETDIR/$POD-dockerfiles-$(getTempFileName)"

    if mkdir -p "$OUTDIR" ; then
      oc rsync "$POD":"/root/buildinfo" "$OUTDIR"
    else
      printf "\n\nError creating the target directory %s.  Unable to retrieve dockerfile.\n\n" "$OUTDIR"
    fi

}



# no args
if (($# == 0)); then
    usage
fi

# Parse arguments
while getopts ":cdfhjmto:p:" opt;
do
    case $opt in
        c)
            GETCONFIG=1
            NOOP=1
        ;;
        d)
            NOCLEAN=1
        ;;
        f)
            GETDOCKERFILES=1
            NOOP=1
        ;;
        h)
            usage
        ;;
        j)
            JDR=1
            NOOP=1
        ;;
        m)
            HEAPDUMP=1
            NOOP=1
        ;;
        o)
            OUTDIR="$OPTARG"
        ;;
        p)
            PODNAME="$OPTARG"
        ;;
        t)
            THREADDUMP=1
            NOOP=1
        ;;
        \?)
            # not valid
            printf "\nUnknown argument : [ %s ]\n\n" "$opt"
            usage
        ;;
        :)
            printf "\nOption -%s requires an argument.\n\n" "$OPTARG"
            usage
        ;;
    esac
done

# Do we have a pod name and tasks to perform?
if [ -z "$PODNAME" ]
then
    printf "\nNo pod name provided.\n\n"
    usage
elif [ -z "$NOOP" ]
then
    printf "\nNo task provided.\n\n"
    usage
fi

# Are we logged into an Opesnhift cluster?
if [ ! loggedIn ]
then
    printf "\n\nNot logged into an Openshift cluster.\n\n"
    exit 1
fi

# See if the pod name is valid
if validatePodName "$PODNAME"; then
    printf "Found %s pod.\n" "$PODNAME"
else
    printf "\n\nPOD %s does not exist.\n\n" "$PODNAME"
    exit 1
fi


# Perform tasks on container
printf "All output will be saved in %s\n\n" "$OUTDIR"

# Retrieve standalone config file
if [ $GETCONFIG -eq 1 ]
then
    printf "\n  **** Retrieving standalone-openshift.xml ****\n\n"
    xstandalone-config "$PODNAME" "$OUTDIR"
fi

# Retrieve dockerfiles
if [ $GETDOCKERFILES -eq 1 ]
then
    printf "\n  **** Retrieving Dockerfiles ****\n\n"
    xdockerfiles "$PODNAME" "$OUTDIR"
fi

# Create a JDR report
if [ $JDR -eq 1 ]
then
    printf "\n  **** Creating JDR report ****\n\n"
    xjdr "$PODNAME" "$OUTDIR"
fi

# Gather heap dump
if [ $HEAPDUMP -eq 1 ]
then
    printf "\n  **** Creating heap dump ****\n\n"
    xheap "$PODNAME" "$OUTDIR"
fi

# Gather thread dumps
if [ $THREADDUMP -eq 1 ]
then
    printf "\n  **** Creating thread dump ****\n\n"
    xthreads "$PODNAME" "$OUTDIR"
fi




exit 0
