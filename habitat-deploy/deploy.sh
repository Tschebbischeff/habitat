#!/usr/bin/env bash

set -euo pipefail

cd "$MODULE_DEPLOY_PATH"

# ### Init

declare -a MODULE_REPOS=()
declare -a MODULE_DIRS=()
export HABITAT_APP_MODULES=""
export HABITAT_APP_SESSION_ID=""

IFS="," read -r -a tmp_modules <<< "${MODULE_LIST}"
for moduleId in "${tmp_modules[@]}"; do
    moduleRepoUrl="$(echo "$moduleId" | xargs)"
    moduleShortName="${moduleRepoUrl##*/}"
    moduleShortName="${moduleShortName%.git}"
    moduleShortName="${moduleShortName##habitat-}"
    if echo "$moduleRepoUrl" | grep -Pqv '^https://'; then # No changes if full URL supplied
        if echo "$moduleRepoUrl" | grep -q '/'; then # User/Org + Repo means GitHub
            moduleRepoUrl="https://github.com/$moduleRepoUrl.git"
        else # Short form for official habitat module
            echo "$moduleRepoUrl" | grep -q '^habitat-' || moduleRepoUrl="habitat-$moduleRepoUrl" # Official modules are always prefixed with 'habitat-', add if necessary
            moduleRepoUrl="https://github.com/Tschebbischeff/$moduleRepoUrl.git"
        fi
    fi
    { [ -n "$HABITAT_APP_MODULES" ] && HABITAT_APP_MODULES="$HABITAT_APP_MODULES,$moduleShortName"; } ||
    HABITAT_APP_MODULES="$HABITAT_APP_MODULES$moduleShortName"
    MODULE_REPOS["${#MODULE_REPOS[@]}"]="$moduleRepoUrl"
    # Clone modules
    # git clone "$moduleRepoUrl"
done
# shellcheck disable=SC2034 # exported variable is used in prepEnvironment function
HABITAT_APP_SESSION_ID="$(cat "/proc/sys/kernel/random/uuid")"


# ### Clone and/or Update modules

for moduleRepoUrl in "${MODULE_REPOS[@]}"; do
    repoDir="$(basename "$(git ls-remote --get-url "$moduleRepoUrl")" .git)"
    MODULE_DIRS["${#MODULE_DIRS[@]}"]="$repoDir"
    if [ -d "$repoDir" ]; then
        if [ "$UPDATE_MODULES" == "yes" ]; then (
            cd "$repoDir"
            git fetch -p -q
            if [ "$(git rev-list "HEAD..@{u}" --count 2>/dev/null || echo 0)" -eq "0" ]; then
                echo "No updates for '$repoDir' available."
            else
                if [ -n "$(git status --porcelain)" ]; then
                    echo "WARNING: Workdir dirty, not downloading the available update."
                else
                    echo "Downloading update for '$repoDir'..."
                    git pull
                fi
            fi
        ); fi
    else
        echo "Initializing module '$repoDir'..."
        git clone "$moduleRepoUrl" "$repoDir"
    fi
done


# ### Start the stack

prepEnvironment() {
    local moduleNameUpper="${1^^}"
    while IFS='=' read -r -d '' n v; do
        if echo "$n" | grep -q '^HABITAT_'; then
            echo "$n" | grep -q '^HABITAT_MODULE_' && continue
            export "${n#"HABITAT_"}"="$v"
            unset -v "$n"
        fi
    done < <(env -0)
    while IFS='=' read -r -d '' n v; do
        if echo "$n" | grep -q '^HABITAT_MODULE_'; then
            if echo "$n" | grep -q "^HABITAT_MODULE_${moduleNameUpper^^}_"; then
                export "${n#"HABITAT_MODULE_${moduleNameUpper^^}_"}"="$v"
            fi
            unset -v "$n"
        fi
    done < <(env -0)
    unset "MODULE_DEPLOY_PATH"
    unset "MODULE_LIST"
    unset "MODULE_ENV_FILE"
    unset "UID"
    unset "GID"
    unset "UPDATE_MODULES"
}

# shellcheck disable=SC2329 # Is used in trap
killApp() {
    trap '' SIGTERM
    echo "Stop signal received, stopping all modules..."
    for moduleDir in "${MODULE_DIRS[@]}"; do
        moduleName="${moduleDir##habitat-}"
        echo "Stopping '$moduleName' ..."
        (
            prepEnvironment "$moduleName"
            docker compose -f "./$moduleDir/compose.yml" down &>/dev/null
        ) &
    done
    # shellcheck disable=SC2046 # Word splitting intentional
    wait $(jobs -p)
    trap - SIGTERM
    exit 0
}

no_container_logs() {
    local attached=""
    while read -r line; do
        [ -z "$attached" ] && echo "$line"
        echo "$line" | grep -Pq "^Attaching to.*$" && attached="_"
    done
}

# Pull and build in parallel, then wait for all
for moduleDir in "${MODULE_DIRS[@]}"; do
    moduleName="${moduleDir##habitat-}"
    echo "Pulling and building latest images for '$moduleName' ..."
    (
        prepEnvironment "$moduleName"
        docker compose -f "./$moduleDir/compose.yml" pull
        docker compose -f "./$moduleDir/compose.yml" build
    ) &
done
# shellcheck disable=SC2046 # Word splitting intentional
wait $(jobs -p)

# Start in parallel, then wait for all, when killed kill all
trap killApp SIGTERM
for moduleDir in "${MODULE_DIRS[@]}"; do
    moduleName="${moduleDir##habitat-}"
    echo "Starting '$moduleName' ..."
    (
        prepEnvironment "$moduleName"
        docker compose -f "./$moduleDir/compose.yml" up 2>&1 | no_container_logs || exit 0 # Ignore command failure for when the container is stopped
    ) &
done
# shellcheck disable=SC2046 # Word splitting intentional
wait $(jobs -p)

echo "All modules have exited."
trap - SIGTERM
exit 0