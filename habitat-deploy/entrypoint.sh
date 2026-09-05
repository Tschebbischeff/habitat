#!/usr/bin/env bash

echo "Habitat Deploy Entrypoint"

UID="$RUN_AS_USER"
GID="$RUN_AS_GROUP"
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
    getent group "$SOCKET_GID" &>/dev/null && \
    GROUP_NAME_DOCKER="$(getent group "${GID}" | cut -d: -f1)" && \
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
echo "Group '$GROUP_NAME' (GID: $GID):"
{
    getent group "${GID}" &>/dev/null && \
    GROUP_NAME="$(getent group "${GID}" | cut -d: -f1)" && \
    echo " Exists as '$GROUP_NAME'"
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
    USER_NAME="$(getent passwd "${UID}" | cut -d: -f1)" && \
    echo " Exists as '$USER_NAME'"
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
echo "Add user '$USER_NAME' (UID: $UID) to group '$GROUP_NAME_DOCKER' (GID: $SOCKET_GID):"
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
    chown -R "${UID}:${GID}" "/habitat-deploy" && \
    echo " Success"
} || {
    echo " Failed"
    exit 5
}

# Drop privileges and run
echo "Dropping privileges and executing CMD..."
exec gosu "$USER_NAME" "$@"