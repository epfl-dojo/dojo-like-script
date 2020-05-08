#!/bin/bash


request=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/orgs/epfl-dojo/repos);

echo $request;
