#!/bin/bash

set -euo pipefail

dist_version=2.329.0
dist_url=https://github.com/actions/runner/releases/download/v$dist_version/actions-runner-linux-x64-$dist_version.tar.gz

default_token=
if [ -f ".github-token" ]; then
    default_token=$(cat ".github-token")
fi

if [ -n "${GITHUB_TOKEN-}" ]; then
    default_token=$GITHUB_TOKEN
fi

function gh() {
    local token=

    while true; do
        case "$1" in
        --token|-t)
            token=$2
            shift 2
            ;;
        *)
            break
            ;;
        esac
    done

    if [ -z "$token" ]; then
        echo "Missing --token" >&2
        exit 1
    fi

    local path="${1-}"

    curl -s -L \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $token" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/$path
}

function setup() {
    mkdir dist
    curl -o actions-runner-linux-x64-$dist_version.tar.gz -L $dist_url
    (cd dist && tar xzf ../actions-runner-linux-x64-$dist_version.tar.gz)
}

function create() {
    local token=$default_token
    local owner=
    local repo=
    local name=

    while [ $# -gt 0 ]; do
        case "$1" in
        --token|-t)
            token=$2
            shift 2
            ;;
        --owner|-o)
            owner=$2
            shift 2
            ;;
        --repo|-r)
            repo=$2
            shift 2
            ;;
        --name|-n)
            name=$2
            shift 2
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
        esac
    done

    if [ -z "$token" ]; then
        echo "Missing --token" >&2
        exit 1
    fi

    if [ -z "$owner" ]; then
        echo "Missing --owner" >&2
        exit 1
    fi

    if [ -z "$repo" ]; then
        echo "Missing --repo" >&2
        exit 1
    fi

    if [ -z "$name" ]; then
        echo "Missing --name" >&2
        exit 1
    fi

    local create_token=$(gh --token $token $owner/$repo/actions/runners/registration-token | jq --raw-output '.token')

    mkdir -p "runners/$name"
    rsync -a --link-dest=../../dist dist/ "runners/$name"

    (
        cd "runners/$name" &&
        ./config.sh \
            --unattended \
            --disableupdate \
            --token $create_token \
            --url "https://github.com/$owner/$repo" \
            --name "$name"
    )
}

function remove() {
    local token=$default_token
    local name=

    while [ $# -gt 0 ]; do
        case "$1" in
        --token|-t)
            token=$2
            shift 2
            ;;
        --name|-n)
            name=$2
            shift 2
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
        esac
    done

    if [ -z "$token" ]; then
        echo "Missing --token" >&2
        exit 1
    fi

    if [ -z "$name" ]; then
        echo "Missing --name" >&2
        exit 1
    fi

    local runner_dir="runners/$name"

    if [ ! -e "$runner_dir" ]; then
        echo "Runner '$name' does not exist" >&2
        exit 1
    fi

    # Find slug (owner/repo)
    local url=$(jq --raw-output '.gitHubUrl' "runners/$name/.runner")
    local slug="${url/'https://github.com/'/}"

    # Get remove token
    local remove_token=$(gh --token $token "$slug/actions/runners/remove-token" | jq --raw-output '.token')

    (cd "runners/$name" && ./config.sh remove --token $remove_token)

    rm -rf "runners/$name"
}

function service() {
    local args=()
    local name=

    while [ $# -gt 0 ]; do
        case "$1" in
        --name|-n)
            name=$2
            shift 2
            ;;
        *)
            args+=("$1")
            shift
            ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "Missing --name" >&2
        exit 1
    fi

    (cd "runners/$name" && ./svc.sh ${args[@]})
}

case "${1-}" in
    setup)
        setup ${@:2}
        ;;
    create|new|mk)
        create ${@:2}
        ;;
    remove|delete|del|rm)
        remove ${@:2}
        ;;
    service|svc)
        service ${@:2}
        ;;
    *)
        echo "Manage self-hosted Github Actions runners"
        echo "Usage: $0 <setup|create|remove|svc> [ARGS...]"
        echo
        echo "Commands:"
        echo
        echo "    setup"
        echo "        Download and install the Github Actions runner package"
        echo
        echo "    create --token <TOKEN> --owner <OWNER> --repo <REPO> --name <NAME>"
        echo "        Create a new runner"
        echo
        echo "        Options:"
        echo "            --token, -t <TOKEN>   Github personal access token"
        echo "            --owner, -o <OWNER>   Github account owner"
        echo "            --repo, -r <REPO>     Github repository name"
        echo "            --name, -n <NAME>     Name of the runner (must be unique per repo)"
        echo
        echo "    remove --token <TOKEN> --name <NAME>"
        echo "        Remove a runner"
        echo
        echo "        Options:"
        echo "            --token, -t <TOKEN>   Github Personal access token"
        echo "            --name, -n <NAME>     Name of the runner to remove"
        echo
        echo "    service [OPTIONS] [ARGS...]"
        echo "        Manage runner service (invoke runner's svc.sh script, needs sudo)"
        echo
        echo "        Options:"
        echo "             --name <NAME>        Name of the runner"
        ;;
esac