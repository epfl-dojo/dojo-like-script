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

RESULTSPERPAGE=100
SENTENCE="stargazed"
INFO_URL="https://github.com/"

# Print the script usage
function usage {
  echo "Usage: ./run.sh"
  echo "  ./run.sh --organisation=epfl-dojo"
  echo "  ./run.sh --user=ponsfrilus"
  echo "  ./run.sh --follow-users-from-org=epfl-dojo"
  echo "Note that you can use -o or -u for short hand."
  echo "This script will need bash > 4.2"
  echo ""
  echo "Be sure that your GitHub Token has the scope 'repo' and 'user'."
  echo ""
  exit 0
}

# parseQueryString "<https://api.github.com/organizations/24317326/repos?page=42>" page
# Return 42
function parseQueryString {
  echo $(echo $1 | grep -oP "(\?|&)${2}=\K([0-9]+)")
}

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
for i in "$@"; do
  case $i in
    -o=*|--org=*|--organisation=*|--organization=*)
      GH_ORG="${i#*=}"
      INFO_URL+="$GH_ORG/"
      shift # past argument=value
    ;;
    -u=*|--user=*)
      GH_USER="${i#*=}"
      INFO_URL+="$GH_USER/"
      shift # past argument=value
    ;;
    -fu=*|-fufo=*|--follow-users-from-org=*)
      GH_ORGFOLLOW="${i#*=}"
      SENTENCE="followed"
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

REQUEST_URL=https://api.github.com/${OrgsOrUsers}/${TARGET}/${MembersOrRepo}?per_page=${RESULTSPERPAGE}
echo "Querying ${REQUEST_URL}"

# Test if user or org exists
test_url=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REQUEST_URL} | jq '.message' 2>/dev/null || true)
if [[ "$test_url" == "\"Not Found\"" ]]; then
  echo "Sorry, $REQUEST_URL not found"
  exit 1
fi

# Get the "link:" in the header (See: https://developer.github.com/v3/#pagination)
link_header=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${REQUEST_URL} -I | grep -i link: || true)
if [[ -z $link_header ]]; then
  page_number=1
  page_url=$REQUEST_URL
  ADD_PG_NUM=false
else
  # Retrieve API link for repo
  page_url=$(echo $link_header | cut -d "," -f 1 | cut -d ">" -f 1)
  page_url="${page_url#"Link: <"}"
  # https://unix.stackexchange.com/a/144330
  # Need bash > 4.2
  page_url=${page_url::-1}
  ADD_PG_NUM=true
  # At this point, we should have an URL like e.g. "https://api.github.com/organizations/14234715/repos?page="
  # parse link:
  link_header=$(echo $link_header | cut -d "," -f 2)
  # Retrieve max page number
  page_number=$(parseQueryString "${link_header}" page)
fi


# For each page...
for i in $(seq $page_number); do

  # Retrieve all repositories names
  if [[ $ADD_PG_NUM == "true" ]]; then
    API_URL=${page_url}${i}
  else
    API_URL=${page_url}
  fi

  if [[ $MembersOrRepo == 'repos' ]]; then
    datas=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${API_URL} | jq '.[].name')
  else
    datas=$(curl -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${API_URL} | jq '.[].login')
  fi

  # For each batch of repositories name...
  for data in $datas; do
    # Thanks to https://stackoverflow.com/a/9733456
    temp="${data%\"}"
    clean_name="${temp#\"}"
    if [[ $MembersOrRepo == 'repos' ]]; then
      API_PUT_URL=https://api.github.com/user/starred/${TARGET}/${clean_name}
    else
      API_PUT_URL=https://api.github.com/user/following/${clean_name}
    fi

    echo $INFO_URL$clean_name

    # Debug: echo curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${API_PUT_URL}
    request=$(curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${API_PUT_URL});
    if [[ $request > 200 && $request < 300 ]]; then
      echo -e "\e[32m✓ \e[39m \e]8;;$INFO_URL$clean_name\e$data\e]8;;\e ${SENTENCE}"
    else
      echo -e "\e[31m✗ \e[39m \e]8;;$INFO_URL$clean_name\e$data\e]8;;\e not ${SENTENCE}"
    fi
  done

done
