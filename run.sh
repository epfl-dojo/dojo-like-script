#!/bin/bash

repositories=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/orgs/epfl-dojo/repos | jq '.[].name')
echo $repositories
repo_name=animated-broccoli

for repo_name in $repositories
do
  echo $repo_name
done

request=$(curl -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/epfl-dojo/${repo_name});

echo $request;


#PUT /user/starred/:owner/:repo


# curl -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/epfl-dojo/animated-broccoli

# curl -X DELETE -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/epfl-dojo/animated-broccoli
