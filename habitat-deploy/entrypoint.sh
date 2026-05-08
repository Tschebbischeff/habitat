#!/usr/bin/env bash

SOCKET_GID="$(stat -c '%g' "/var/run/docker.sock")"
[ -z "$UID" ] && UID="$(stat -c '%u' "$MODULE_DEPLOY_PATH")"
[ -z "$GID" ] && GID="$(stat -c '%g' "$MODULE_DEPLOY_PATH")"

# Create groups and users
getent group docker_host &>/dev/null || addgroup -g "${SOCKET_GID}" docker_host
getent group "${GID}" &>/dev/null || addgroup -g "${GID}" habitat
GROUP_NAME="$(getent group "${GID}" | cut -d: -f1)"
getent passwd "${UID}" &>/dev/null || adduser -u "${UID}" -g "Habitat" -D -H habitat -G "$GROUP_NAME"
USER_NAME="$(getent passwd "${UID}" | cut -d: -f1)"
addgroup "$USER_NAME" docker_host

# Fix permissions
chown -R "${UID}:${GID}" "/habitat-deploy"

# Drop privileges and run
exec gosu "$USER_NAME" "$@"