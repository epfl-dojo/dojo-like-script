#!/usr/bin/env bash
VERSION="0.0.2"
# set -e -x

if ! [[ "$(command -v jq)" ]]; then
   echo -e "\e[31mWARNING:\e[39m jq is not installed";
   echo -e "\e[34mCOMMAND:\e[39m sudo apt install jq";
   exit 1;
fi

# Ensure that GHTOKEN is defined
if [ -e $GHTOKEN ]; then
  echo -e "\e[31mFAIL:\e[39m GHTOKEN not found"
  echo -e "Please generate a GitHub API token from https://github.com/settings/tokens and export it: "
  echo -e "\e[34mCOMMAND:\e[39m export GHTOKEN=yourkey"
  exit 1
fi

RESULTSPERPAGE=100
SENTENCE="stargazed"
INFO_URL="https://github.com/"

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

header

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

    # Debug: echo curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${API_PUT_URL}
    request=$(curl -s -w "%{http_code}" -X PUT -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GHTOKEN}" -s ${API_PUT_URL});
    if [[ $request > 200 && $request < 300 ]]; then
      echo -e "\e[32m✓\e[39m \e]8;;$INFO_URL$clean_name\a$clean_name\e]8;;\a ${SENTENCE}"
    else
      echo -e "\e[31m✗\e[39m \e]8;;$INFO_URL$clean_name\a$clean_name\e]8;;\a ${SENTENCE}"
    fi
  done
done
