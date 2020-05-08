#!/bin/bash


request=$(curl -H "Accept: application/vnd.github.v3+json" -i https://api.github.com/orgs/epfl-dojo/repos);

echo $request;