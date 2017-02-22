#!/bin/bash

#************************************************************************************************
# Name          : javaCacheHandler.sh
# Version       : 1.0
# Date          : 2016/05/18
# Author        : Thomas SCHWENDER
#************************************************************************************************

usage()
{
    echo "Usage: javaCacheHandler OPTION [JNLP_FILE]"
    echo "DO NOT FORGET to update the paths in fonction initCommonConstants()"
    echo
    echo "-j"
    echo "    List the jars, and their content, present in the Java cache."
    echo "    Also display the jar real name from the INDEX.LIST if exists."
    echo "-l"
    echo "    List the applications stored in the Java cache, with the full path in cache of their associated JNLP file."
    echo
    echo "-u JNLP_FILE"
    echo "    uninstall the cached application corresponding to the given jnlp file (full path in Java cache needed)."
    echo
    echo "A common usage is to, first get the JNLP path of your application using \"-l\" option, then uninstall it using \"-u\" option."
    echo 
};

initCommonConstants()
{
    OS=`uname`
    CURRENT_DATE=`date +%Y%m%d-%H%M%S`

    case $OS in 
        MINGW64_NT-6.1*)
            PREFIX_PATH=""
        ;;
        CYGWIN_NT-6.1-WOW*)
            # prefix used by Cygwin
            PREFIX_PATH="/cygdrive"
        ;;
        *)
            echo "To make this script work for $OS you might want to edit it and add a case option." 1>&2
            exit 1
        ;;
    esac

    # DO NOT FORGET to upate the following paths for your environment!
    JAR_PATH="$PREFIX_PATH/<path to JDK bin folder>"
    JAVA_CACHE_PATH="$PREFIX_PATH/<path to Java Cache folder, generally %USERPROFILE%/AppData/LocalLow/Sun/Java/Deployment/cache/6.0 on Windows>"
    TMP_PATH="$PREFIX_PATH/<path to some tmp folder>"

    RESULT_JAVACACHEHANDLER="$TMP_PATH/javaCacheHandler-listJars-$CURRENT_DATE.txt"
}

initConstantsForListJars()
{
    TMP_BUFFER="$TMP_PATH/tmpBuffer$$"
    INDEX_FOLDER="META-INF"
    INDEX_PATH="$INDEX_FOLDER/INDEX.LIST"
}

printHeader()
{
    echo "*******************************************************************" >> $RESULT_JAVACACHEHANDLER
    echo "OS for cacheViewer = $OS" | tee -a $RESULT_JAVACACHEHANDLER
    echo "Process started at $CURRENT_DATE" >> $RESULT_JAVACACHEHANDLER
    echo "*******************************************************************" >> $RESULT_JAVACACHEHANDLER
    echo >> $RESULT_JAVACACHEHANDLER  
}

listJars()
{
    cd "$TMP_PATH"
    for currentFile in `find "$JAVA_CACHE_PATH" -type f ! \( -name "*.idx" -o -name "lastAccessed" -o -name "splash.xml" -o -name "appIcon.xml" \)`
    do
        fileType=`file -b "$currentFile"`
        echo "Cached file $currentFile of type $fileType"
        if [ "$fileType" == 'Java archive data (JAR)' ]
        then

            echo "**************************************************************************************************************************************" >> $RESULT_JAVACACHEHANDLER
            echo "**** found jar $currentFile" >> $RESULT_JAVACACHEHANDLER
            

            # if exist, extract the INDEX.LIST, to get the real name of the jar
            "$JAR_PATH"/jar -xf $currentFile $INDEX_PATH
            if [ -e "$INDEX_PATH" ]
            then
                jarName=`grep .*\.jar "$INDEX_PATH"`
                echo "******** it corresponds to $jarName" >> $RESULT_JAVACACHEHANDLER
                rm -rf "$INDEX_FOLDER"
            fi

            # get the content of the jar
            "$JAR_PATH/jar" -tvf $currentFile 2>/dev/null > $TMP_BUFFER
            echo "******** it contains: " >> $RESULT_JAVACACHEHANDLER
            cat "$TMP_BUFFER" >> $RESULT_JAVACACHEHANDLER

        fi
    done

    if [ -e "$TMP_BUFFER" ]
    then
        rm "$TMP_BUFFER"
    fi 
}

listApplications()
{
    echo "Applications found in Java cache:"
    echo

    for lapFile in `find "$JAVA_CACHE_PATH" -name "*.lap"`
    do
        echo "lap file is $lapFile"
        # Deletes longest match until a "-" from BACK of lap file full name
        # /c/tools/Java/Deployment/Cache/6.0/17/454b091-3ec602a43c6fd627696fc271afced5ac71e775e206edf0c2c872c79ddd4252cd-6.0.lap      >> /c/tools/Java/Deployment/Cache/6.0/17/454b091
        # /c/tools/Java/Deployment/Cache/6.0/17/454b091                                                                               >> 454b091
        lapFilePrefix="${lapFile%%-*}"
        lapFilePrefix="${lapFilePrefix##*/}"

        lapFileDirName=`dirname "$lapFile"`
        jnlpFile=`find "$lapFileDirName" -name $lapFilePrefix* ! -name "*.lap" ! -name "*.idx"`

        # for capturing only groups in grep, see http://stackoverflow.com/questions/18892670/can-not-extract-the-capture-group-with-neither-sed-nor-grep
        environment=`grep -soP "codebase=\"http://\K(.*)(?=:.*\">)" "$jnlpFile"`
        applicationName=`grep -soP "<title>\K(.*)(?=</title>)" "$jnlpFile"`

        if [ -n "$environment" ] && [ -n "$applicationName" ]
        then
            echo "    $applicationName for environment $environment"
            echo "    JNLP file is $jnlpFile"
        else
            echo "    no application associated with the lap file"
        fi

    done
}

uninstallApplication()
{
    if [ -e "$JNLP_FILE" ]
    then
        jnlpValid=`grep -oP "\K(<jnlp spec)" "$JNLP_FILE"`
        if [ "$jnlpValid" != "<jnlp spec" ]
        then
            echo "The file given in 2nd parameter is probably not a JNLP file..."
            exit 1
        fi
    fi

    # "$JAR_PATH"/javaws -uninstall "$JNLP_FILE" &>/dev/null
    "$JAR_PATH"/javaws -uninstall "$JNLP_FILE"
}

##########
## MAIN ##
##########

initCommonConstants

ACTION="$1"

case "$ACTION" in
# option "list the jars"
-j)
    initConstantsForListJars
    printHeader
    listJars
;;
# option "list applications in cache"
-l)
    listApplications
;;
# option "uninstall application from cache"
-u)
    JNLP_FILE="$2"
    uninstallApplication
;;
# usage in any other cases
*) usage && exit 1;;
esac

echo "finished!"
exit 0
