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
    {
        [ -n "$HABITAT_APP_MODULES" ] && \
        HABITAT_APP_MODULES="$HABITAT_APP_MODULES,$moduleShortName"
    } ||
        HABITAT_APP_MODULES="$HABITAT_APP_MODULES$moduleShortName"
    MODULE_REPOS["${#MODULE_REPOS[@]}"]="$moduleRepoUrl"
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
    # Side-effects will modify environment, only call in subshell
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
            if echo "$n" | grep -q "^HABITAT_MODULE_${moduleNameUpper}_"; then
                export "${n#"HABITAT_MODULE_${moduleNameUpper}_"}"="$v"
            fi
            unset -v "$n"
        fi
    done < <(env -0)
    unset "PROJECT_NAME"
    unset "MODULE_DEPLOY_PATH"
    unset "MODULE_LIST"
    unset "MODULE_ENV_FILE"
    unset "NETWORK_POOL"
    unset "RUN_AS_USER"
    unset "RUN_AS_GROUP"
    unset "UPDATE_MODULES"
    unset "UPGRADE_MODULES"
}

# shellcheck disable=SC2329 # Is used in trap
killApp() {
    trap '' SIGTERM
    echo "Stop signal received, stopping all modules..."
    for moduleDir in "${MODULE_DIRS[@]}"; do
        (
            moduleName="${moduleDir##habitat-}"
            prepEnvironment "$moduleName"
            echo "Stopping '$moduleName' ..."
            docker compose \
                -f "./$moduleDir/compose.yml" \
            down &>/dev/null
        ) &
    done
    # shellcheck disable=SC2046 # Word splitting intentional
    wait $(jobs -p)
    trap - SIGTERM
    exit 0
}

# Pull and build in parallel, then wait for all
if [ "$UPGRADE_MODULES" == "yes" ]; then
    for moduleDir in "${MODULE_DIRS[@]}"; do
        (
            moduleName="${moduleDir##habitat-}"
            prepEnvironment "$moduleName"
            echo "Pulling latest images for '$moduleName'..."
            if docker compose \
                -f "./$moduleDir/compose.yml" \
                --progress plain \
            pull; then
                echo "Building '$moduleName'..."
                docker compose \
                    -f "./$moduleDir/compose.yml" \
                    --progress plain \
                build
            fi
        ) &
    done
    allSuccess="_"
    # shellcheck disable=SC2046 # Word splitting intentional
    for jobPID in $(jobs -p); do
        wait "$jobPID" || allSuccess=""
    done
    [ -n "$allSuccess" ] || {
        echo "Some pull and/ or build operations failed, see logs above."
        exit 1
    }
else
    echo "Not pulling or building any images, set UPGRADE_MODULES to 'yes' to enable."
fi

# Start in parallel, then wait for all, when killed kill all
trap killApp SIGTERM
for moduleDir in "${MODULE_DIRS[@]}"; do
    (
        moduleName="${moduleDir##habitat-}"
        prepEnvironment "$moduleName"
        echo "Starting '$moduleName' ..."
        if ! docker compose \
            -f "./$moduleDir/compose.yml" \
            --progress plain \
        up \
            -d
        then
            exit 1
        fi
        echo "Waiting for '$moduleName' to exit..."
        # shellcheck disable=SC2046 # Word splitting intentional
        docker compose \
            -f "./$moduleDir/compose.yml" \
            --progress plain \
        wait $(
            docker compose \
                -f "./$moduleDir/compose.yml" \
                --progress plain \
            config --services
        )
    ) &
done
# shellcheck disable=SC2046 # Word splitting intentional
wait $(jobs -p)

echo "All modules have exited."
trap - SIGTERM
exit 0