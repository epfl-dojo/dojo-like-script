# dojo-like-script

A script to like all repo from a user or an organisation, or follow all users
from an organisation on GitHub.


## Usage

  1. Generate an [access token](https://github.com/settings/tokens)
     * Scope: **repo**
     * Scope: **user** 
  1. Export the GHTOKEN env var (`export GHTOKEN=yourGitHubAccessToken`)
  1. Run the script with `./run.sh` (the default org is [epfl-dojo](https://github.com/epfl-dojo))


## Script options
  - Display help: `./run.sh --help`
  - You can specify an user with:
     - `./run.sh --user=username`
     - `./run.sh -u=username`
  - You can specify an organisation with:
     - `./run.sh --organisation=orgname`
     - `./run.sh --organization=orgname`
     - `./run.sh --org=orgname`
     - `./run.sh -o=orgname`
  - You can specify organisation members to follow with:
     - `./run.sh --follow-users-from-org=orgname`
     - `./run.sh -fufo=orgname`


## Links
  * Generate an [access token](https://github.com/settings/tokens)
  * [Star a repository](https://developer.github.com/v3/activity/starring/#star-a-repository-for-the-authenticated-user)


## Support

If you like this script, you can show your support by using it with the
following usernames ([contributors](https://github.com/epfl-dojo/dojo-like-script/graphs/contributors)):

```
./run.sh -u=loichu
./run.sh -u=ponsfrilus
./run.sh -u=richmartins
./run.sh -u=Roccom14
./run.sh -u=SaphireVert
./run.sh -u=TacticsCH
./run.sh -u=zuzu59
```
