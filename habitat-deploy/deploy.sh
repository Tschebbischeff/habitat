#!/usr/bin/env bash

set -euo pipefail

# ### Declarations and Definitions

cd "$MODULE_DEPLOY_PATH"
STATUS_FILE="$1"; shift
[ -f "$STATUS_FILE" ] || exit 1

declare -A MODULE_REPOS
declare -A MODULE_DIRS
declare -A MODULE_UPDATED

# ### Functions

setStatus() {
    echo "$1" >"$STATUS_FILE"
}

prepEnvironment() {
    # WARNING: Side-effects will modify environment, only call from within subshell
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
    unset "UPGRADE_MODULES_FORCE_BUILD"
    unset "UPGRADE_MODULES_SEQUENTIAL"
}

# shellcheck disable=SC2329 # Is used in trap
killApp() {
    trap '' SIGTERM
    setStatus "stopping"
    echo "Stop signal received, stopping all modules..."
    for moduleName in "${!MODULE_DIRS[@]}"; do
        (
            prepEnvironment "$moduleName"
            echo "Stopping '$moduleName' ..."
            docker compose \
                -f "./${MODULE_DIRS[$moduleName]}/compose.yml" \
            down &>/dev/null
        ) &
    done
    # shellcheck disable=SC2046 # Word splitting intentional
    wait $(jobs -p)
    setStatus "stopped"
    echo "All modules stopped."
    trap - SIGTERM
    exit 0
}


# ### Init
setStatus "init"

mapfile -t tmp_module_list < <(printf "%s" "$MODULE_LIST" | sed -E 's/([^\\]|^),/\1\n/g')
for moduleSpec in "${tmp_module_list[@]}"; do
    moduleRepoUrl="$(echo "$moduleSpec" | grep -Po '^[ \t]*\K.*[^ \t]')"
    if echo "$moduleRepoUrl" | grep -Pqv '^https://'; then # No changes if full URL supplied
        if echo "$moduleRepoUrl" | grep -q '/'; then # User/Org + Repo means GitHub
            moduleRepoUrl="https://github.com/$moduleRepoUrl.git"
        else # Short form for official habitat module
            echo "$moduleRepoUrl" | grep -q '^habitat-' || moduleRepoUrl="habitat-$moduleRepoUrl" # Official modules are always prefixed with 'habitat-', add if necessary
            moduleRepoUrl="https://github.com/Tschebbischeff/$moduleRepoUrl.git"
        fi
    fi
    moduleShortName="${moduleRepoUrl##*/}"
    moduleShortName="${moduleShortName%.git}"
    moduleShortName="${moduleShortName##habitat-}"
    # Populate arrays
    MODULE_REPOS[$moduleShortName]="$moduleRepoUrl"
    MODULE_DIRS[$moduleShortName]="$(basename "$(git ls-remote --get-url "$moduleRepoUrl")" .git)"
    MODULE_UPDATED[$moduleShortName]=""
done; unset moduleSpec moduleRepoUrl moduleShortName
unset tmp_module_list
# shellcheck disable=SC2155  # Return value is of no interest
export HABITAT_APP_MODULES="$(printf ',%s' "${!MODULE_REPOS[@]}" | grep -Po '^,\K.*')"
# shellcheck disable=SC2155  # Return value is of no interest
export HABITAT_APP_SESSION_ID="$(cat "/proc/sys/kernel/random/uuid")"


# ### Clone and/or Update modules
setStatus "update"

for moduleName in "${!MODULE_REPOS[@]}"; do
    moduleRepoUrl="${MODULE_REPOS[$moduleName]}"
    moduleRepoDir="${MODULE_DIRS[$moduleName]}"
    if [ -d "$moduleRepoDir" ]; then
        if [ "$UPDATE_MODULES" == "yes" ]; then
            currentWorkdir="$(pwd)"
            cd "$moduleRepoDir"
            git fetch -p -q
            if [ "$(git rev-list "HEAD..@{u}" --count 2>/dev/null || echo 0)" -eq "0" ]; then
                echo "No updates for '$moduleName' available."
            else
                if [ -n "$(git status --porcelain)" ]; then
                    echo "WARNING: Workdir dirty, not downloading the available update."
                else
                    echo "Downloading update for '$moduleName'..."
                    git pull && \
                        MODULE_UPDATED[$moduleName]="_"
                fi
            fi
            cd "$currentWorkdir"; unset currentWorkdir
        fi
    else
        echo "Initializing module '$moduleName'..."
        git clone "$moduleRepoUrl" "$moduleRepoDir" && \
            MODULE_UPDATED[$moduleName]="_"
    fi
done; unset moduleName moduleRepoUrl moduleRepoDir


# ### Pull and build if needed and/ or enabled
setStatus "upgrade"

allSuccess="_"
declare -A moduleByPID
for moduleName in "${!MODULE_DIRS[@]}"; do
    (
        moduleDir="${MODULE_DIRS[$moduleName]}"
        moduleUpdated="${MODULE_UPDATED[$moduleName]}"
        upgradeModules="$UPGRADE_MODULES"
        forceBuild="$UPGRADE_MODULES_FORCE_BUILD"
        prepEnvironment "$moduleName"
        [ "$upgradeModules" == "yes" ] \
            && echo "Pulling latest images for '$moduleName'..." \
            || echo "Pulling missing images for '$moduleName'..."
        imageHashesBefore="$(
            docker compose \
                -f "./$moduleDir/compose.yml" \
                --progress plain \
            config \
                --images \
            2>/dev/null | sort | xargs -r docker image inspect --format '{{.Id}}' 2>/dev/null
        )"
        if docker compose \
            -f "./$moduleDir/compose.yml" \
            --progress plain \
        pull \
            --policy "$([ "$upgradeModules" == "yes" ] && echo "always" || echo "missing")"
        then
            imageHashesAfter="$(
                docker compose \
                    -f "./$moduleDir/compose.yml" \
                    --progress plain \
                config \
                    --images \
                2>/dev/null | sort | xargs -r docker image inspect --format '{{.Id}}' 2>/dev/null
            )"
            if [ "$forceBuild" == "yes" ] || [ "$imageHashesBefore" != "$imageHashesAfter" ] || [ -n "$moduleUpdated" ]; then
                echo "Building '$moduleName'..."
                docker compose \
                    -f "./$moduleDir/compose.yml" \
                    --progress plain \
                build
            else
                echo "No updates in module repository or images, running everything from local caches."
            fi
        fi
    ) &
    jobPID="$!"
    moduleByPID["$jobPID"]="$moduleName"
    if [ "$UPGRADE_MODULES_SEQUENTIAL" == "yes" ]; then
        wait "$jobPID"
        exitCode="$?"
        [ "$exitCode" -eq 0 ] || {
            echo "Upgrading '$moduleName' failed with exit code '$exitCode'."
            allSuccess=""
            break
        }
    fi
    unset jobPID
done; unset moduleName
# shellcheck disable=SC2046 # Word splitting intentional
for jobPID in $(jobs -p); do
    wait "$jobPID"
    exitCode="$?"
    [ "$exitCode" -eq 0 ] || {
        echo "Upgrading '${moduleByPID["$jobPID"]}' failed with exit code '$exitCode'."
        allSuccess=""
        break
    }
done; unset jobPID
[ -n "$allSuccess" ] || {
    echo "Some pull and/ or build operations failed, see logs above."
    exit 1
}
unset allSuccess

# ### Start modules
setStatus "starting"

trap killApp SIGTERM
for moduleName in "${!MODULE_DIRS[@]}"; do
    moduleDir="${MODULE_DIRS[$moduleName]}"
    (
        prepEnvironment "$moduleName"
        echo "Starting '$moduleName' ..."
        if ! docker compose \
            -f "./$moduleDir/compose.yml" \
            --progress plain \
        up \
            --pull never \
            --no-build \
            -d \
        2> >(grep -Pv '^.*level=warning msg="(Found orphan containers.*|secret file .* does not exist)"$' >&2)
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
done; unset moduleName moduleDir


# ### Wait for containers to finish or for SIGTERM
setStatus "started"

# shellcheck disable=SC2046 # Word splitting intentional
wait $(jobs -p)


# ### Exit
setStatus "stopped"

echo "All modules have exited."
trap - SIGTERM
exit 0