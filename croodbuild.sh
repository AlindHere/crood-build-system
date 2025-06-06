#!/bin/bash
set -e

curl -fsSL -o crood https://alind-public-binaries.s3.ap-south-1.amazonaws.com/crood/crood-1.0.0
chmod +x crood


git fetch
git tag --list | grep -v - | tail -1 >tag.txt
if IFS=. read -r major minor patch <tag.txt || [ -n "$major" ]; then
    if [ ! -z $BITBUCKET_TAG ]; then
    VERSION_TAG=$BITBUCKET_TAG
    elif [ ! -z $BITBUCKET_PR_ID ]; then
    VERSION_TAG="$major.$minor.$patch-pr-${BITBUCKET_PR_ID}.$BITBUCKET_BUILD_NUMBER"
    elif [ ! -z $BITBUCKET_BRANCH ]; then
    BRANCH_NAME=$(echo -n "$BITBUCKET_BRANCH" | tr -c -s '[:alnum:]' '-')
    VERSION_TAG="$major.$minor.$patch-$BRANCH_NAME.$BITBUCKET_BUILD_NUMBER"
    else
    BITBUCKET_COMMIT_SHORT=$(echo $BITBUCKET_COMMIT | cut -c1-7)
    VERSION_TAG="1.0.0-$BITBUCKET_COMMIT_SHORT.$BITBUCKET_BUILD_NUMBER"
    fi
else 
  BITBUCKET_COMMIT_SHORT=$(echo $BITBUCKET_COMMIT | cut -c1-7)
  VERSION_TAG="1.0.0-$BITBUCKET_COMMIT_SHORT.$BITBUCKET_BUILD_NUMBER"
fi

echo $VERSION_TAG >tag.txt

echo "======================================" 

echo "New version = $(<tag.txt)"

echo "======================================" 

APP_NAME=${BITBUCKET_REPO_SLUG}

buildNotes="buildnotes.txt"

./crood -a ${APP_NAME}  -f ${CROOD_CONFIG_PATH} -b ${BITBUCKET_BUILD_NUMBER} -t ${VERSION_TAG} --output-notes-path ${buildNotes}


echo "=================== CHECKING FOR HELM CHART INDEXING ===================" 

#CF_HELM_REPO CF_HELM_REPO_USER CF_HELM_REPO_PASS
helmVersionCheck () {
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  helm repo add my-helm-repo ${1} --username ${2}  --password ${3}
  if [[ $(helm search repo my-helm-repo/${BITBUCKET_REPO_SLUG} --versions --devel | grep $VERSION_TAG) ]]
  then
    echo "CHART VERSION HAS BEEN INDEXED SUCCESSFULLY!!!"
  else
    echo "CHART VERSION HAS NOT BEEN INDEXED!!!"
  fi
}

helmVersionCheck ${HELM_REPO} ${HELM_REPO_USER} ${HELM_REPO_PASS}


if [ -f "${buildNotes}" ]; then
  buildNotesComment=`cat ${buildNotes}`
  curl --request POST \
  --url "https://api.bitbucket.org/2.0/repositories/${BITBUCKET_WORKSPACE}/${BITBUCKET_REPO_SLUG}/commit/${BITBUCKET_COMMIT}/comments" \
  --header "Authorization: Basic ${BB_BUILD_BOT_AUTH}" \
  --header 'Content-Type: application/json' \
  --data '{
  "content": {
    "raw": "'"${buildNotesComment//$'\n'/\<br \/\>}"'"
  }
}'
fi

