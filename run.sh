#!/usr/bin/env bash

# set -e -x

VERSION="0.2.0"
RESULTSPERPAGE=100
SENTENCE="stargazed"
SECONDS=0

if ! [[ "$(command -v jq)" ]]; then
   echo -e "\e[31mWARNING:\e[39m jq is not installed";
   echo -e "\e[34mCOMMAND:\e[39m sudo apt install jq";
   exit 1;
fi

function header {
  echo -e "\e[32m-----------------------------------------------------------"
  echo -e " ___       _       _    _ _         ___         _      _   "
  echo -e "|   \ ___ (_)___  | |  (_) |_____  / __| __ _ _(_)_ __| |_ "
  echo -e "| |) / _ \| / _ \ | |__| | / / -_) \__ \/ _| '_| | '_ \  _|"
  echo -e "|___/\___// \___/ |____|_|_\_\___| |___/\__|_| |_| .__/\__|"
  echo -e "         |__/                         \e[5m\e[37mver: $VERSION\e[25m\e[32m |_|       "
  echo -e "   Source: \e[39mhttps://github.com/epfl-dojo/dojo-like-script\e[32m"
  echo -e "-----------------------------------------------------------\e[39m"
}

# Print the script usage
function usage {
  header
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

function doCurlRequest {
  request=$(curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json, application/json" -H "${TOKEN_STRING} ${TOKEN}" -s ${API_PUT_URL});
  if [[ $request > 200 && $request < 300 ]]; then
    echo -ne "\r \033[K \e[32m✓\e[39m \e]8;;$INFO_URL$clean_name\a$clean_name\e]8;;\a ${SENTENCE}"
  else
    echo -e "\n \e[31m✗\e[39m \e]8;;$INFO_URL$clean_name\a$clean_name\e]8;;\a ${SENTENCE} \n"
  fi
}

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
for i in "$@"; do
  case $i in
    -d|--debug)
      set -e -x
    ;;
    -gh|--github)
      WEBSITE="github"
      # Ensure that GHTOKEN is defined
      if [ -e $GHTOKEN ]; then
        echo -e "\e[31mFAIL:\e[39m GHTOKEN not found"
        echo -e "Please generate a GitHub API token from https://github.com/settings/tokens and export it: "
        echo -e "\e[34mCOMMAND:\e[39m export GHTOKEN=yourkey"
        exit 1
      fi
      TOKEN=$GHTOKEN
      TOKEN_STRING="Authorization: token"
    ;;
    -gl|--gitlab)
      WEBSITE="gitlab"
      # Ensure that GLTOKEN is defined
      if [ -e $GLTOKEN ]; then
        echo -e "\e[31mFAIL:\e[39m GLTOKEN not found"
        echo -e "Please generate a GitLab API token from https://gitlab.com/profile/personal_access_tokens and export it: "
        echo -e "\e[34mCOMMAND:\e[39m export GLTOKEN=yourkey"
        exit 1
      fi
      TOKEN=$GLTOKEN
      TOKEN_STRING="PRIVATE-TOKEN:"
    ;;
    -o=*|--org=*|--organisation=*|--organization=*)
      ORG="${i#*=}"
      INFO_URL+="$ORG/"
      shift # past argument=value
    ;;
    -u=*|--user=*)
      GIT_USER="${i#*=}"
      INFO_URL+="$GIT_USER/"
      shift # past argument=value
    ;;
    -fu=*|-fufo=*|--follow-users-from-org=*)
      ORGFOLLOW="${i#*=}"
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

header

# Ensure one of the options is set
if [[ -z $ORG && -z $GIT_USER && -z $ORGFOLLOW ]]; then
  ORG=epfl-dojo
  TOKEN=$GHTOKEN
  TOKEN_STRING="Authorization: token"
fi
if [[ -z $WEBSITE ]]; then
  WEBSITE="github"
  TOKEN=$GHTOKEN
  TOKEN_STRING="Authorization: token"
fi
if [[ ! -z $ORG ]]; then
  OrgsOrUsers='orgs'
  MembersOrRepo='repos'
  TARGET=$ORG
  echo "Looking for $ORG repositories"
fi
if [[ ! -z $GIT_USER ]]; then
  OrgsOrUsers='users'
  MembersOrRepo='repos'
  TARGET=$GIT_USER
  echo "Looking for $GIT_USER repositories"
fi
if [[ ! -z $ORGFOLLOW ]]; then
  OrgsOrUsers='orgs'
  MembersOrRepo='members'
  TARGET=$ORGFOLLOW
  echo "Looking for $ORGFOLLOW users"
fi

INFO_URL="https://${WEBSITE}.com/"
REQUEST_URL=https://api.${WEBSITE}.com/${OrgsOrUsers}/${TARGET}/${MembersOrRepo}?per_page=${RESULTSPERPAGE}
#echo "Querying ${REQUEST_URL}"

# Test if user or org exists
test_url=$(curl -H "Accept: application/vnd.github.v3+json, application/json" -H "${TOKEN_STRING} ${TOKEN}" -s ${REQUEST_URL} | jq '.message' 2>/dev/null || true)
if [[ "$test_url" == "\"Not Found\"" ]]; then
  echo "Sorry, $REQUEST_URL not found"
  exit 1
fi

REPO_NUMBER=$(curl -H "Accept: application/vnd.github.v3+json, application/json" -H "${TOKEN_STRING} ${TOKEN}" -s "https://api.${WEBSITE}.com/${OrgsOrUsers}/${TARGET}" | jq '.public_repos')

# Get the "link:" in the header (See: https://developer.github.com/v3/#pagination)
link_header=$(curl -H "Accept: application/vnd.github.v3+json, application/json" -H "${TOKEN_STRING} ${TOKEN}" -s ${REQUEST_URL} -I | grep -i link: || true)
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
    datas=$(curl -H "Accept: application/vnd.github.v3+json, application/json" -H "${TOKEN_STRING} ${TOKEN}" -s ${API_URL} | jq '.[].name')
  else
    datas=$(curl -H "Accept: application/vnd.github.v3+json, application/json" -H "${TOKEN_STRING} ${TOKEN}" -s ${API_URL} | jq '.[].login')
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

    doCurlRequest &

  done
done
wait
echo -e "\n\e[32mRuntime: ${SECONDS}s for ${REPO_NUMBER} entries."
