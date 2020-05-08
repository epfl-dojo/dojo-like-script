#!/bin/bash

if [ -e $GHTOKEN ]; then
  echo "FAIL: GHTOKEN not found"
  echo "Please generate a GitHub API token from https://github.com/settings/tokens"
  echo "and export it: "
  echo "export GHTOKEN=yourkey"
  exit 1
fi

repositories=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/orgs/epfl-dojo/repos | jq '.[].name')
echo $repositories

for repo_name in $repositories
do
  echo $repo_name
  # Thanks to https://stackoverflow.com/a/9733456
  temp="${repo_name%\"}"
  clean_name="${temp#\"}"
  request=$(curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/epfl-dojo/${clean_name});
  echo $request
  if [[ $request > 200 && $request < 400 ]]; then
    echo "Good job"
  else
    echo "Failed"
  fi
done
