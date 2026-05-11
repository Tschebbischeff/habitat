[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue?style=flat)](./LICENSE)
![Development: Prototyping](https://img.shields.io/badge/Development-Prototyping-orange?style=flat)
![Version](https://img.shields.io/badge/dynamic/json?label=Version&color=yellow&style=flat&url=https%3A%2F%2Fraw.githubusercontent.com%2Ftschebbischeff%2Fhabitat%2Frefs%2Fheads%2Fmain%2Fmetadata.json&query=%24.version)

# Habitat

> [!CAUTION]
> **🚧 This project is currently under heavy development, any information may be subject to change. 🚧**

Habitat is a modular ecosystem designed to turn one or multiple home lab devices into a fully orchestrated private cloud.

Habitat modules provide a variety of functionality that can be mixed and matched according to your needs. \
Each of the modules is designed as an opinionated docker stack that can be deployed on its own or together with other modules by sharing the same docker network.

## Officially Available Modules

 - **[Path](https://github.com/Tschebbischeff/habitat-path)** \
 Network routing and reverse proxy
 - **[Scent](https://github.com/Tschebbischeff/habitat-scent)** \
 Identity provider, LDAP directory and access control
 - **[Vista](https://github.com/Tschebbischeff/habitat-vista)** \
 Central dashboards and device entry points
 - **[Chatter](https://github.com/Tschebbischeff/habitat-chatter)** \
 Message queue for realtime communication between modules
 - **[Hoard](https://github.com/Tschebbischeff/habitat-hoard)** \
 Time-series database and persistent storage
 - **[Thicket](https://github.com/Tschebbischeff/habitat-thicket)** \
 Relational database
 - **[Vigil](https://github.com/Tschebbischeff/habitat-vigil)** \
 Device monitoring, visualization and alerting
 - **[Sight](https://github.com/Tschebbischeff/habitat-sight)** \
 Real-time video streaming
 - **[Stash](https://github.com/Tschebbischeff/habitat-sight)** \
 Nextcloud

## Our Principles

![TODO](https://img.shields.io/badge/TODO-Coming_Soon_(TM)-red?style=flat)

## Features

This repository deploys a list of habitat modules on the host via Docker-outside-of-Docker.

### Planned
 - **Private Git Repositories** \
 Cloning modules from private repositories

## Getting Started

### Deployment Requirements

 - Git
 - Docker

### Quick Start

Run or follow the instructions in this snippet:

```sh
# Intended for Linux based systems, you may succeed in running this on WSL as well
# 1. Create a new folder for our setup
mkdir "habitat" && cd "habitat"
# 2. Clone the deployment project
git clone "https://github.com/Tschebbischeff/habitat.git" "habitat-deploy"
# 3. Create a folder for the deployment project to clone the habitat modules to
mkdir "habitat-modules"
# 4. Create the .env file for the unified configuration
cat <<EOF >".env"
# Compose configuration
COMPOSE_FILE="$PWD/habitat-deploy/compose.yml"
# Deployment configuration
MODULE_DEPLOY_PATH="\$PWD/habitat-modules"
MODULE_LIST="path,scent,vista" # Add your desired modules
MODULE_ENV_FILE="\$PWD/.env"
# Global module configuration
HABITAT_APP_HOST="my-habitat.example.com" # Change to your hostname
HABITAT_APP_NAME_LABEL="MyHabitat" # Pick a proper label
HABITAT_TIMEZONE="$(timedatectl show | sed -n 's/^Timezone=\(.*\)$/\1/p' 2>/dev/null)" # Fill out if empty or wrong
HABITAT_VOLUME_DIR="$PWD/.volumes" # Volumes used for persistent data (target for backups)
HABITAT_SECRETS_DIR="$PWD/.secrets" # Folder containing secrets, replace with "/run/secrets" if secrets are mounted there for example when using sops-nix
# Module-specific configuration
# No module-specific config
# Example: HABITAT_MODULE_PATH_TIMEZONE="Etc/UTC"
EOF
# 5. Modify the .env file to your liking
"${EDITOR:-${VISUAL:-vi}}" ".env"
# 6. Start the deployment
docker compose up
```

### Deployment Configuration

The application is designed to be controlled exclusively with environment variables and secrets.

 - [List of environment variables](#environment-variables-for-deployment)
 - [List of secrets](#secrets)

#### Deployment Variables

The existing [.env](./.env) file contains defaults for the environment variables necessary at build-time and is designed to let you overwrite any of those environment variables via exports from your shell before running the application.

*Example:*
```sh
MODULE_LIST="path,scent,vista" docker compose up -d
```

### Module Configuration

To properly configure any environment variables that can be passed on to modules, you will need to create a `_.env` file in the root of the cloned repository.

*Example:*
```sh
# ./_.env
HABITAT_APP_HOST="my-habitat.example.com"
HABITAT_APP_NAME_LABEL="MyHabitat"
HABITAT_TIMEZONE="Europe/Madrid"
HABITAT_SECRETS_DIR="/run/secrets"
```

> [!TIP]
> The file `_.env` is included in [.gitignore](./.gitignore) and is guaranteed to not interfere with future updates via `git pull`/ `git checkout`.

Alternatively create the file somewhere else and point the deployment container to it by setting the environment variable `MODULE_ENV_FILE`, e.g.: \
`MODULE_ENV_FILE="/path/to/my-habitat-module-config.env" docker compose up -d`

### Unified Configuration

Optionally, you can also define the environment variables required by the deployment container itself in the same file as the module environment variables.

You will need to instruct docker compose to use the same file for interpolation of variables inside the compose.yml via the `--env-file` argument. \
I.e.: `docker compose --env-file "/path/to/habitat-config.env" up -d`

*Example:*
```sh
# /path/to/habitat-config.env
MODULE_DEPLOY_PATH="$PWD/habitat-modules"
MODULE_LIST="path,scent,vista"
MODULE_ENV_FILE="/path/to/habitat-config.env"
HABITAT_APP_HOST="my-habitat.example.com"
HABITAT_APP_NAME_LABEL="MyHabitat"
HABITAT_TIMEZONE="Europe/Madrid"
HABITAT_SECRETS_DIR="/run/secrets"
```

#### Fully Separate Configuration

Alternatively, you can define a single, fully self-contained, `.env` file in a fresh folder somewhere and point it to the docker compose file instead, this way the shipped `.env` file in the repository root has lower precedence and only the variables you choose will be overridden ([Compose Documentation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/#local-env-file-versus-project-directory-env-file)).

```sh
# /path/to/my-habitat/.env
COMPOSE_FILE="/path/to/repository/compose.yml"
MODULE_DEPLOY_PATH="$PWD/habitat-modules" # This will clone the modules into a subfolder next to this .env file
MODULE_LIST="path,scent,vista"
MODULE_ENV_FILE="$PWD/.env"
HABITAT_APP_HOST="my-habitat.example.com"
HABITAT_APP_NAME_LABEL="MyHabitat"
HABITAT_TIMEZONE="Europe/Madrid"
HABITAT_SECRETS_DIR="/run/secrets"
```

### Environment Variables for Deployment

At build-time Docker requires the following environment variables to be populated:

| Name | Description | Example | Default |
| :-- | :-- | :-- | :-- |
| `MODULE_DEPLOY_PATH` | An absolute path to clone the selected modules to. Must be absolute, so that path matching works correctly between the Host and the deployment container. | `/foo/bar/habitat-modules` | `$PWD/habitat-modules` |
| `MODULE_LIST` | A comma separated list of module names that are started in the same docker namespace (same project name) as this module. | `path,thicket,stash,vista` | `path,scent,vista` |
| `MODULE_ENV_FILE` | Path to an env-file containing variables that should be passed to modules. | `/foo/bar/module-config.env` | `./_.env` |
| `RUN_AS_USER` | UID to run the deployment container as. If empty, the UID is inferred from the `MODULE_DEPLOY_PATH` volume. | `1000` | *Empty* |
| `RUN_AS_GROUP` | GID to run the deployment container as. If empty, the GID is inferred from the `MODULE_DEPLOY_PATH` volume. | `100` | *Empty* |
| `UPDATE_MODULES` | Whether to update all modules before starting. | `no` | `yes` |

The module list supports the following formats:
 - Full HTTPS Git repository URL (e.g.: `https://github.com/Tschebbischeff/habitat-path.git`)
 - Short form for GitHub repositories (e.g.: `Tschebbischeff/habitat-path`)
 - Short form official module name (e.g. `habitat-path`, `path`)

### Environment Variables for Modules

The following environment variables will be generated and passed to all modules automatically:

| Name | Description | Generation Method |
| :-- | :-- | :-- |
| `APP_MODULES` | A comma separated list of module names that are started in the same docker namespace (same project name) as this module. | Generated from list of modules given to deployment container via `MODULE_LIST`. The list will be the shortest naming form of the repository name only, if the repository name starts with `habitat-`, that prefix is stripped. |
| `APP_SESSION_ID` | A session ID used for synchronization of configuration between modules, should change every time all modules are restarted in unison and remain unchanged if a single module is restarted without being updated. | Generated randomly from `cat /proc/sys/kernel/random/uuid` each time the deployment container is started. |

You can override and define environment variables for one or all modules as follows:
 - Prefix `HABITAT_` will have its prefix stripped and passed on to all modules
 - Prefix `HABITAT_MODULE_$moduleName_` will have its prefix stripped and passed to the module with the name `$moduleName` only
   - The `$moduleName` must match the shortest form of the repository name, i.e. the name as it is supplied in the `APP_MODULES` variable (see above)

> [!WARNING]
> *These overrides need to be defined in a `_.env` file in the repository's root directory, they cannot be supplied via exports from your shell.*

Example:

```sh
# ./_.env
HABITAT_APP_HOST="my-habitat.example.com"
HABITAT_SECRETS_DIR="/run/secrets"
HABITAT_MODULE_PATH_FOO="bar"
```

> [!WARNING]
> These definitions do not override the automatic generation performed by the deployment container.

The following environment variables are commonly used by all modules and can be overriden for all or some of the modules with the above prefixes:

| Name | Description | Example | Default |
| :-- | :-- | :-- | :-- |
| `APP_HOST` | The main URL the device will be reachable at. | `my-habitat.example.com` | *Empty* |
| `APP_MODULES` | A comma separated list of module names that are started in the same docker namespace (same project name) as this module. | `path,scent,vista` | *Empty* |
| `APP_SESSION_ID` | A session ID used for synchronization of configuration between modules, should change every time all modules are restarted in unison and remain unchanged if a single module is restarted without being updated. | `$(cat /proc/sys/kernel/random/uuid)` | *Empty* |
| `APP_NETWORK_POOL` | The pool of IP addresses for the module containers, must match pool of all other modules in the same application. | `172.19.0.0/16` | `172.18.0.0/16` |
| `APP_NAME_HOST` | The prefix for all docker networks and containers, that this application will create. Also used as the internal hostname within all containers. | `my-habitat` | `habitat` |
| `APP_NAME_LABEL` | The human readable name of the device. | `My Habitat` | `Habitat` |
| `TIMEZONE` | Timezone identifier passed on to containers. | `Europe/Paris` | `Europe/Berlin` |
| `VOLUME_DIR` | The directory in which [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/) are placed *(Currently only named volumes are used)*. | `/path/to/my/volumes` | `./volumes` |
| `ENV_DIR` | The directory in which .env files for containers can be placed to override the default runtime config. | `/path/to/my/env` | `./env.d` |
| `SECRETS_DIR` | The directory in which files containing secrets for containers are placed. | `/run/secret` | `./secrets` |

For additional environment variables check out the documentation of the specific module.

### Secrets

*The deployment container does not require any secrets, refer to the documentation of the modules you want to deploy for additional secrets that might be needed.*

<!--
> [!NOTE]
> All secrets are expected to be files within a single folder, each file containing the value of the secret. \
> This folder can be set via environment variable (`SECRETS_DIR`) itself and defaults to `./.secrets` (git-ignored folder). \
> All secrets must be present at run-time.

| (File) Name | Description | Documentation / How to Obtain |
| :-- | :-- | :-- |
|  | The deployment container does not require any secrets, refer to the documentation of the modules you want to deploy for additional secrets. |  |
-->

### Run the Application

 - Create a folder `habitat-modules` within the current working directory or within the root directory of the repository
 - Run `docker compose up -d` from the root directory of the repository or from the directory containing your `.env` file
   - You can run `MODULE_DEPLOY_PATH="$(pwd)/habitat-modules" docker compose up -d` with your choice for `MODULE_DEPLOY_PATH` instead, to define your own location for the modules, **the path must be absolute and exist**
   - If modules require environment variables, you must set them appropriately for the deployment container aswell, see the section on supplying [environment variables for modules](#environment-variables-for-modules) for more information
 - Shutting down the resulting `habitat` service will also shut down all of the modules

> [!TIP]
> The `habitat-modules` folder is included in [.gitignore](./.gitignore) and is guaranteed to not interfere with future updates via `git pull`/ `git checkout`.

## Acknowledgments and Licensing

This project is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](./LICENSE).

Copyright (c) 2026, [Tschebbischeff](https://github.com/Tschebbischeff). \
All rights reserved to the extent permitted by the AGPLv3.

For third-party license details and attribution, please see [Third-Party Licenses](./THIRD-PARTY-LICENSES.md).
