#!/bin/bash

#************************************************************************************************
# Name 					: manualDeployMaven3Dependencies.sh
# Version 				: 1.1
# Date 					: 2014/02/27
# Author 				: Thomas SCHWENDER
#************************************************************************************************

### Check parameters ###
usage()
{
	echo "${0} -r actifacts_folder"
	echo "Deploy the given artifacts (jars) in the correct Maven 3 REMOTE repo."
	echo
	echo "Rules:"
	echo " - \"artifacts_folder\" must an absolute, NOT relative, path"
	echo " - Artifacts whose name doesn't start with \"<project prefix>\" go in the Dependencies repo"
	echo " - Repo of other artifacts depends on their version, snapshot or not"
	echo
	echo "${0} -l actifacts_list_file"
	echo "Deploy the given list of artifacts in the correct Maven 3 REMOTE repo."
	echo "Those artifacts MUST BE PRESENT in your maven 1 local repo."
	echo
	echo "Rules:"
	echo " - Jars listed in the file must match the pattern:"
	echo "   GroupId:ArtifactId:Type:Version"
	echo " - only jars (Type = jar) will be deployed"
	echo " - Artifacts whose GroupId isn't \"project\" go in the Dependencies repo"
	echo " - Repo of other artifacts depends on their version, snapshot or not"
	echo
	echo "Available repo:"
	echo " - Snapshots repo        : <nexus server URL>/nexus/content/repositories/<project repo for SNAPSHOTS>/"
	echo " - Releases repo         : <nexus server URL>/nexus/content/repositories/<project repo for RELEASES>/"
	echo " - Dependencies repo     : <nexus server URL>/nexus/content/repositories/<project repo for 3rd-party DEPENDENCIES>/"
	echo
	echo "LOG file created in given \"artifacts_folder\" for option \"-r\", or in the current folder for option \"-l\" "
	echo
};

initLogFile() {
	LOG_PATH="$LOG_DIRECTORY/artifacts_deployed_to_remote_repos.log"
	echo "LOG_PATH=$LOG_PATH"

	echo "**************************************************************************************************************************************************************************">>$LOG_PATH
	date +"%Y-%m-%d %T">>$LOG_PATH
}

getArtifactPrefix() {
	# Deletes longest match until a "-" from BACK of artifact full name to know if it is a 3rd party dependency (not starting with "project")
	# project-MyJar-1.2.3.jar 	>> project
	# MyJar-1.2.3.jar 			>> MyJar
	projectPrefix=${dependencyName%%-*}
	#echo "getArtifactPrefix=$projectPrefix"
};

getArtifactNameWithoutExtension() {
	# Get the artifact name without extension
	artifactNoExtension=${dependencyName:0:${#i}-4}
	#echo "getArtifactNameWithoutExtension=$artifactNoExtension"
};

getVersion() {
	# Deletes longest match until a "-" from FRONT of $artifactNoExtension to have the artifact version
	# project-MyJar-1.2.3 			>> 1.2.3
	# project-MyJar-1.2.3-SNAPSHOT 	>> SNAPSHOT
	version=${artifactNoExtension##*-}
	version=${version^^}

	if [ $version == "SNAPSHOT" ]; then
		version=`expr "$artifactNoExtension" : '.*-\(.*-SNAPSHOT\)'`
		version=${version^^}
	fi
	#echo "getVersion=$version"
};

getArtifactId() {
	# Get the artifact name without version
	artifactId=${artifactNoExtension:0:${#artifactNoExtension}-${#version}-1}
	#echo "getArtifactId=$artifactId"
};

echoDeployInfo() {
	message
	message "#### Artifact to be deployed ####"
	message
	message "  file = $file"
	message "  groupId = $groupId"
	message "  artifactId = $artifactId"
	message "  version = $version"
	message "  remoteRepo = $remoteRepo"
	message "  repoURL = $repoURL"
}

deployDependency() {
	echoDeployInfo

	message
	# now deploy each jar to the remote Maven 3 repo using deploy:deploy-file
	mvn deploy:deploy-file -DgroupId="$groupId" \
	-DartifactId="$artifactId" \
	-Dversion="$version" \
	-Dpackaging="jar" \
	-Dfile="$file" \
	-DrepositoryId="$remoteRepo" \
	-Durl="$repoURL" | tee -a $LOG_PATH

	# purging the log file from unwanted "1/50 KB  " lines
	sed -r '/[0-9]+\/[0-9]+ KB.*/d' $LOG_PATH > tmp && mv tmp $LOG_PATH
}

message() {
	echo "$1"
	echo "$1">>$LOG_PATH
}

## MAIN ##

REPO_BASE_URL="<nexus server URL>/nexus/content/repositories/"
SNAPSHOTS_REPO="SNAPSHOTS"
RELEASES_REPO="RELEASES"
THIRD_DEPENDENCIES_REPO="DEPENDENCIES"

ACTION="$1"

case "$ACTION" in
# option "folder of jars"
-r)
    ARTIFACTS_PATH=${2}
    cd "$ARTIFACTS_PATH"

	LOG_DIRECTORY="."
	initLogFile

	for dependencyName in *.jar
	do
		file=$ARTIFACTS_PATH/$dependencyName


		getArtifactPrefix
		getArtifactNameWithoutExtension
		getVersion
		getArtifactId

		if [[ $version == *SNAPSHOT* ]]; then
			repoURL=$REPO_BASE_URL$SNAPSHOTS_REPO
			remoteRepo=$SNAPSHOTS_REPO
			# Maven GAV
			groupId="project"
			version="HEAD-SNAPSHOT"
		else
			repoURL=$REPO_BASE_URL$RELEASES_REPO
			remoteRepo=$RELEASES_REPO
			# Maven GAV
			groupId="project"
		fi

		if [ $projectPrefix != "project" ]; then
			repoURL=$REPO_BASE_URL$THIRD_DEPENDENCIES_REPO
			remoteRepo=$THIRD_DEPENDENCIES_REPO
			# Maven GAV
			groupId=$artifactId
		fi

		deployDependency

	done
	message
	message "#### Done ####"
	message
;;

# option "list of jars"
-l)
	ARTIFACTS_LIST_FILE_PATH=$2

	LOG_DIRECTORY="."
	initLogFile

	# The following "sed" replacing Windows \r\n by Unix \n is to enable the use by Git Bash (porting of Bash for Windows, hence the \r\n)
	# Without it, the "while IFS=: read -r groupId artifactId type version" will not work for the final "version" token
	cat "$ARTIFACTS_LIST_FILE_PATH" | sed 's/\r\n/\n/g' | 
	while IFS=: read -r groupId artifactId type version
	do

		if [ $type != "jar" ]; then
			echo "WARNING: dependency $groupId / $artifactId / $type / $version is NOT a jar and will not be deployed." | tee -a $LOG_PATH
		else
			echo "Dependency GAV = $groupId / $artifactId / $type / $version" | tee -a $LOG_PATH

			# Git Bash
			file="<maven 1 repository path>/$groupId/jars/$artifactId-$version.jar"
			# CYGWIN
			# file="\\<maven 1 repository path>/"$groupId"/jars/"$artifactId"-"$version".jar"
			if [ -e $file ]; then
				echo "Dependency path in Maven 1 local repo is: $file" | tee -a $LOG_PATH

				if [ $groupId == "project" ]; then
					if [[ $version == *SNAPSHOT* ]]; then
					repoURL=$REPO_BASE_URL$SNAPSHOTS_REPO
					remoteRepo=$SNAPSHOTS_REPO
					else
						repoURL=$REPO_BASE_URL$RELEASES_REPO
						remoteRepo=$RELEASES_REPO
					fi
				# if the groupId is NOT "project", it means that it is MANDATORILY a 3rd party dependency
				else
					repoURL=$REPO_BASE_URL$THIRD_DEPENDENCIES_REPO
					remoteRepo=$THIRD_DEPENDENCIES_REPO
				fi

				deployDependency
			else
				echo "ERROR! file $file was not found! Dependency skipped."
			fi
		fi
	done
;;

# usage in any other cases
*) usage && exit 1;;
esac

echo
exit 0

