#!/usr/bin/env bash

echo "Habitat Deploy Entrypoint"

SOCKET_GID="$(stat -c '%g' "/var/run/docker.sock")"

[ -z "$RUN_AS_USER" ] && RUN_AS_USER="$(stat -c '%u' "$MODULE_DEPLOY_PATH")"
[ -z "$RUN_AS_GROUP" ] && RUN_AS_GROUP="$(stat -c '%g' "$MODULE_DEPLOY_PATH")"

GROUP_NAME_DOCKER="docker_host"
GROUP_NAME="habitat"
USER_NAME="habitat"

# Create groups and users
echo "Checking groups and users..."
echo "Group '$GROUP_NAME_DOCKER' (GID: $SOCKET_GID):"
{
    getent group "$SOCKET_GID" &>/dev/null && \
    GROUP_NAME_DOCKER="$(getent group "${SOCKET_GID}" | cut -d: -f1)" && \
    echo " Exists as '$GROUP_NAME_DOCKER'"
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
echo "Group '$GROUP_NAME' (GID: $RUN_AS_GROUP):"
{
    getent group "${RUN_AS_GROUP}" &>/dev/null && \
    GROUP_NAME="$(getent group "${RUN_AS_GROUP}" | cut -d: -f1)" && \
    echo " Exists as '$GROUP_NAME'"
} || {
    echo " Creating"
    {
        addgroup -g "${RUN_AS_GROUP}" "$GROUP_NAME" && \
        echo " Success"
    } || {
        echo " Failed"
        exit 2
    }
}
echo "User '$USER_NAME' (UID: $RUN_AS_USER):"
{
    getent passwd "${RUN_AS_USER}" &>/dev/null && \
    USER_NAME="$(getent passwd "${RUN_AS_USER}" | cut -d: -f1)" && \
    echo " Exists as '$USER_NAME'"
} || {
    echo " Creating"
    {
        adduser -u "${RUN_AS_USER}" -g "$USER_NAME" -D -H "$USER_NAME" -G "$GROUP_NAME" && \
        echo " Success"
    } || {
        echo " Failed"
        exit 3
    }
}
echo "Add user '$USER_NAME' (UID: $RUN_AS_USER) to group '$GROUP_NAME_DOCKER' (GID: $SOCKET_GID):"
{
    getent group "${SOCKET_GID}" | cut -d: -f4 | grep -Pq '(^|,)'"$USER_NAME"'(,|$)' && \
    echo " Already assigned"
} || {
    {
        addgroup "$USER_NAME" docker_host && \
        echo " Success"
    } || {
        echo " Failed"
        exit 4
    }
}

# Fix permissions
echo "Fixing permissions on /habitat-deploy"
{
    chown -R "${RUN_AS_USER}:${RUN_AS_GROUP}" "/habitat-deploy" && \
    echo " Success"
} || {
    echo " Failed"
    exit 5
}

# Export additional variables
export DOCKER_CONFIG="/tmp/.docker"

# Drop privileges and run
echo "Dropping privileges and executing CMD..."
exec gosu "$USER_NAME" "$@"