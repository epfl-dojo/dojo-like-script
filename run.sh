#!/bin/bash


request=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/orgs/epfl-dojo/repos);

echo $request;


#PUT /user/starred/:owner/:repo


# curl -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/epfl-dojo/animated-broccoli

# curl -X DELETE -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/epfl-dojo/animated-broccoli
