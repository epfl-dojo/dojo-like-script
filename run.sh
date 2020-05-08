#!/bin/bash

set -e -x

# Ensure that GHTOKEN is defined
if [ -e $GHTOKEN ]; then
  echo "FAIL: GHTOKEN not found"
  echo "Please generate a GitHub API token from https://github.com/settings/tokens"
  echo "and export it: "
  echo "export GHTOKEN=yourkey"
  exit 1
fi

# Print the script usage
function usage {
  echo "Usage: ./run.sh --org=epfl-dojo"
  exit 0
}

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
for i in "$@"
do
case $i in
  -o=*|--org=*|--organisation=*|--organization=*)
  GH_ORG="${i#*=}"
  shift # past argument=value
  ;;
  -u=*|--user=*)
  GH_USER="${i#*=}"
  shift # past argument=value
  ;;
  -h|--help)
  usage
  ;;
  *)
    # unknown option
  ;;
esac
done

# Ensure one of the options is set
if [[ -z $GH_ORG && -z $GH_USER ]]; then
  usage
fi

if [[ ! -z $GH_ORG ]]; then
  OrgsOrUsers='orgs'
  TARGET=$GH_ORG
  echo "Looking for $GH_ORG repositories"
fi
if [[ ! -z $GH_USER ]]; then
  OrgsOrUsers='users'
  TARGET=$GH_USER
  echo "Looking for $GH_USER repositories"
fi

REPO_URL=https://api.github.com/${OrgsOrUsers}/${TARGET}/repos

# Test if user or org exists
test_url=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REPO_URL} | jq '.message')

if [[ "$test_url" == "\"Not Found\"" ]]; then
  echo "Sorry, $REPO_URL not found"
  exit 1
fi

# echo "DEBUG: curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REPO_URL} | jq '.[].name'"
repositories=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REPO_URL} | jq '.[].name')
echo $repositoriesactact

for repo_name in $repositories
do
  echo $repo_name
  # Thanks to https://stackoverflow.com/a/9733456
  temp="${repo_name%\"}"
  clean_name="${temp#\"}"
  request=$(curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/${TARGET}/${clean_name});
  echo $request
  if [[ $request > 200 && $request < 400 ]]; then
    echo "Good job"
  else
    echo "Failed"
  fi
done
