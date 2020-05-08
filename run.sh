#!/bin/bash

if [ -e $GHTOKEN ]; then
  echo "FAIL: GHTOKEN not found"
  echo "Please generate a GitHub API token from https://github.com/settings/tokens"
  echo "and export it: "
  echo "export GHTOKEN=yourkey"
  exit 1
fi

echo -n "Like a User or an Organization? [U/O] : "
read userInput
if [[ "$userInput" == "O" ]] || [[ "$userInput" == "o" ]];
then
    IN="orgs"
elif [[ "$userInput" == "U" ]] || [[ "$userInput" == "u" ]];
then
    IN="users"
fi

echo -n "Whose repositories do you want to like? : "
read userInput
if [[ -n "$userInput" ]]
then
  TARGET=$userInput
fi
    echo ... Liking ${TARGET} repositories ...


repositories=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/${IN}/${TARGET}/repos | jq '.[].name')
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
