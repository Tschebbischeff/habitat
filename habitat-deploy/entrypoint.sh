#!/usr/bin/env bash

echo "Habitat Deploy Entrypoint"

SOCKET_GID="$(stat -c '%g' "/var/run/docker.sock")"
[ -z "$UID" ] && UID="$(stat -c '%u' "$MODULE_DEPLOY_PATH")"
[ -z "$GID" ] && GID="$(stat -c '%g' "$MODULE_DEPLOY_PATH")"
GROUP_NAME_DOCKER="docker_host"
GROUP_NAME="habitat"
USER_NAME="habitat"

# Create groups and users
echo "Checking groups and users..."
echo "Group '$GROUP_NAME_DOCKER' (GID: $SOCKET_GID):"
{
    getent group "$GROUP_NAME_DOCKER" &>/dev/null && \
    echo " Exists"
} || {
    echo " Creating"
    {
        addgroup -g "${SOCKET_GID}" "$GROUP_NAME_DOCKER" && \
        echo " Success"
    } || {
        echo " Failed"
        exit 1
    }
}
echo "Group '$GROUP_NAME' (GID: $GID):"
{
    getent group "${GID}" &>/dev/null && \
    echo " Exists"
} || {
    echo " Creating"
    {
        addgroup -g "${GID}" "$GROUP_NAME" && \
        echo " Success"
    } || {
        echo " Failed"
        exit 2
    }
}
echo "User '$USER_NAME' (UID: $UID):"
{
    getent passwd "${UID}" &>/dev/null && \
    echo " Exists"
} || {
    echo " Creating"
    {
        adduser -u "${UID}" -g "$USER_NAME" -D -H "$USER_NAME" -G "$GROUP_NAME" && \
        echo " Success"
    } || {
        echo " Failed"
        exit 3
    }
}
echo "Add user '$USER_NAME' (UID: $UID) to group '$GROUP_NAME_DOCKER' (GID: $GID):"
{
    addgroup "$USER_NAME" docker_host && \
    echo " Success"
} || {
    echo " Failed"
    exit 4
}

# Fix permissions
echo "Fixing permissions on /habitat-deploy"
{
    chown -R "${UID}:${GID}" "/habitat-deploy" && \
    echo " Success"
} || {
    echo " Failed"
    exit 5
}

# Drop privileges and run
echo "Dropping privileges and executing CMD..."
exec gosu "$USER_NAME" "$@"