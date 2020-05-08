#!/bin/bash

# set -e -x

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
for i in "$@"; do
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
  # usage
  GH_ORG=epfl-dojo
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
test_url=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REPO_URL} | jq '.message' 2>/dev/null || true)

if [[ "$test_url" == "\"Not Found\"" ]]; then
  echo "Sorry, $REPO_URL not found"
  exit 1
fi

# Get the "link:" in the header (See: https://developer.github.com/v3/#pagination)
link_header=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REPO_URL} -I | grep -i link:)

# Retrieve API link for repo
page_url=$(echo $link_header | cut -d "," -f 1 | cut -d ">" -f 1)
page_url="${page_url#"Link: <"}"
page_url=${page_url::-1}
# At this point, we should have an URL like e.g. "https://api.github.com/organizations/14234715/repos?page="
# Retrieve max page number
page_number=$(echo $link_header | cut -d "," -f 2 | cut -d "=" -f 2 | cut -d ">" -f 1)

# For each page...
for i in $(seq $page_number); do
  # Retrieve all repositories names
  repositories=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${page_url}${i} | jq '.[].name')

  # For each batch of repositories name...
  for repo_name in $repositories; do
    # Thanks to https://stackoverflow.com/a/9733456
    temp="${repo_name%\"}"
    clean_name="${temp#\"}"
    request=$(curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/${TARGET}/${clean_name});
    # echo $request
    if [[ $request > 200 && $request < 300 ]]; then
      echo "$repo_name is now stargazed"
    else
      echo "Failed to stargaze $repo_name"
    fi
  done
done
