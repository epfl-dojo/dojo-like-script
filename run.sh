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
  echo "Usage: ./run.sh"
  echo "  ./run.sh --organisation=epfl-dojo"
  echo "  ./run.sh --user=ponsfrilus"
  echo "Note that you can use -o or -u for short hand."
  echo "This script will need bash > 4.2"
  exit 0
}

# parseQueryString "<https://api.github.com/organizations/24317326/repos?page=42>" page
# Return 42
function parseQueryString {
  number=$(echo $1 | grep -oP "(\?|&)${2}=\K([0-9]+)")
  echo $number
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
  -fufo=*|--follow-users-from-org=*)
  GH_ORGFOLLOW="${i#*=}"
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
if [[ -z $GH_ORG && -z $GH_USER && -z $GH_ORGFOLLOW ]]; then
  # usage
  GH_ORG=epfl-dojo
fi

if [[ ! -z $GH_ORG ]]; then
  OrgsOrUsers='orgs'
  MembersOrRepo='repos'
  TARGET=$GH_ORG
  echo "Looking for $GH_ORG repositories"
fi
if [[ ! -z $GH_USER ]]; then
  OrgsOrUsers='users'
  MembersOrRepo='repos'
  TARGET=$GH_USER
  echo "Looking for $GH_USER repositories"
fi
if [[ ! -z $GH_ORGFOLLOW ]]; then
  OrgsOrUsers='orgs'
  MembersOrRepo='members'
  TARGET=$GH_ORGFOLLOW
  echo "Looking for $GH_ORGFOLLOW users"
fi

REQUEST_URL=https://api.github.com/${OrgsOrUsers}/${TARGET}/${MembersOrRepo}   #${resultsPerPage}
# Test if user or org exists
test_url=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REQUEST_URL} | jq '.message' 2>/dev/null || true)

if [[ "$test_url" == "\"Not Found\"" ]]; then
  echo "Sorry, $REQUEST_URL not found"
  exit 1
fi

# Get the "link:" in the header (See: https://developer.github.com/v3/#pagination)
link_header=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REQUEST_URL} -I | grep -i link: || true)
# <echo $link_header

if [[ -z $link_header ]]; then
  page_number=1
  page_url=$REQUEST_URL
  ADD_PG_NUM=false
else
  # Retrieve API link for repo
  echo $page_url
  page_url=$(echo $link_header | cut -d "," -f 1 | cut -d ">" -f 1)
  page_url="${page_url#"Link: <"}"
  # https://unix.stackexchange.com/a/144330
  # Need bash > 4.2
  page_url=${page_url::-1}
  ADD_PG_NUM=true
  # At this point, we should have an URL like e.g. "https://api.github.com/organizations/14234715/repos?page="
  # parse link:
  link_header=$(echo $link_header | cut -d "," -f 2 | cut -d ";" -f 1)
  # Retrieve max page number
  page_number=$(parseQueryString ${link_header} page)
fi


# For each page...
for i in $(seq $page_number); do
  if [[ $MembersOrRepo == 'repos' ]]; then
    # Retrieve all repositories names
    if [[ $ADD_PG_NUM == "true" ]]; then
      repositories=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${page_url}${i} | jq '.[].name')
    else
      repositories=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${page_url} | jq '.[].name')
    fi
      # For each batch of repositories name...
      for repo_name in $repositories; do
        # Thanks to https://stackoverflow.com/a/9733456
        temp="${repo_name%\"}"
        clean_name="${temp#\"}"
        request=$(curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/starred/${TARGET}/${clean_name});
        # echo $request
        if [[ $request > 200 && $request < 300 ]]; then
          echo "$repo_name is now stargazed!!!"
        else
          echo "Failed to stargaze $repo_name"
        fi
      done
    else
      if [[ $ADD_PG_NUM == "true" ]]; then
        members=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${page_url}${i} | jq '.[].login')
      else
        members=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${page_url} | jq '.[].login')
      fi
        # For each batch of members name...
        for user_name in $members; do
          # Thanks to https://stackoverflow.com/a/9733456
          temp="${user_name%\"}"
          clean_name="${temp#\"}"
          request=$(curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s https://api.github.com/user/following/${clean_name});
          # echo $request
          # echo $clean_name
          if [[ $request > 200 && $request < 300 ]]; then
            echo "You are now following https://github.com/$clean_name"
          else
            echo "Failed to follow https://github.com/$clean_name"
          fi
        done
    fi
done



#https://api.github.com/organizations/24317326/repos?page=2

#https://api.github.com/organizations/24317326/repos?per_page=5&page=2

#https://api.github.com/organizations/24317326/repos?per_page=5&page=
