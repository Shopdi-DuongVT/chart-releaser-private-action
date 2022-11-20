#!/usr/bin/env bash

# Copyright 2021 Miguel Araujo

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

# Global Variables
charts_dir=charts
owner=
repo=
charts_repo_url=
token=${GH_TOKEN:-}

usage() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help               Display help
    -d, --charts-dir         The charts directory (default: charts)
    -u, --charts-repo-url    The GitHub Pages URL to the charts repo (default: https://<owner>.github.io/<repo>)
    -o, --owner              The repo's owner
    -r, --repo               The repo's name
    -t, --token              GitHub Personal Access Token (PAT) for authentication
EOF
}

main() {
    parse_command_line "$@"
    
    : "${token:?GitHub token must be set via 'GH_TOKEN' env variable or '--token' flag}"

    pushd $(pwd) > /dev/null

    echo 'Getting latest tag...'
    local latest_tag=$(get_latest_tag)

    echo "Discovering changed charts since '$latest_tag'..."
    local changed_charts=()
    readarray -t changed_charts <<< "$(get_changed_charts "$latest_tag")"
    
    if [[ -n "${changed_charts[*]}" ]]; then
        download_chart_releaser

        if [ -d ".cr-release-packages" ]; then rm -Rf .cr-release-packages; fi
        mkdir -p .cr-release-packages

        if [ -d ".cr-index" ]; then rm -Rf .cr-index; fi
        rm -rf .cr-index
        mkdir -p .cr-index

        for chart in "${changed_charts[@]}"; do
            if [[ -d "$chart" ]]; then
                package_chart "$chart"
            else
                echo "Chart '$chart' no longer exists in repo. Skipping it..."
            fi
        done

        upload_charts
        generate_index
    else
        echo "Nothing to do. No chart changes detected."
    fi

    popd > /dev/null
}

parse_command_line() {
    while [[ -n "${1:-}" ]]; do
        case $1 in
            -h|--help)
                usage
                exit
                ;;
            -d|--charts-dir)
                if [[ -n "${2:-}" ]]; then
                    charts_dir="$2"
                    shift
                else
                    echo "ERROR: '-d|--charts-dir' cannot be empty." >&2
                    usage
                    exit 1
                fi
                ;;
            -u|--charts-repo-url)
                if [[ -n "${2:-}" ]]; then
                    charts_repo_url="$2"
                    shift
                else
                    echo "ERROR: '-u|--charts-repo-url' cannot be empty." >&2
                    usage
                    exit 1
                fi
                ;;
            -o|--owner)
                if [[ -n "${2:-}" ]]; then
                    owner="$2"
                    shift
                else
                    echo "ERROR: '--owner' cannot be empty." >&2
                    usage
                    exit 1
                fi
                ;;
            -r|--repo)
                if [[ -n "${2:-}" ]]; then
                    repo="$2"
                    shift
                else
                    echo "ERROR: '--repo' cannot be empty." >&2
                    usage
                    exit 1
                fi
                ;;
            -t|--token)
                if [ -n "${2:-}" ]; then
                    token="$2"
                    shift
                else
                    echo "ERROR: '--token' flag cannot be empty." >&2
                    usage
                    exit 1
                fi
                ;;
            *)
                usage
                break
        esac
        shift
    done

    if [ -z $owner ]; then
        echo "ERROR: '-o|--owner' is required." >&2
        usage
        exit 1
    fi

    if [ -z $repo ]; then
        echo "ERROR: '-r|--repo' is required." >&2
        usage
        exit 1
    fi

    if [ -z $charts_repo_url ]; then
        charts_repo_url="https://$owner.github.io/$repo"
    fi
}

download_chart_releaser() {
    if [ -f "cr" ]; then
        echo "Chart Releaser binary already exists."
    else
        echo "Downloading latest Chart Release binary..."

        local DOWNLOAD_URL=$(curl -s https://api.github.com/repos/helm/chart-releaser/releases/latest \
            | grep browser_download_url \
            | grep linux_amd64 \
            | cut -d '"' -f 4)

        local output_file_name=cr.tar.gz

        curl -s -L --create-dirs -o ./$output_file_name https://github.com/helm/chart-releaser/releases/download/v1.4.1/chart-releaser_1.4.1_linux_amd64.tar.gz

        tar -xzf $output_file_name
        rm README.md LICENSE $output_file_name
    fi
}

package_chart() {
    local chart=$1
    echo "Packaging chart '$chart'"
    ./cr package "$chart"
}

upload_charts() {
    echo 'Uploading charts...'

    ./cr upload -o "$owner" -r "$repo" -t $token --skip-existing
}

generate_index() {
    echo 'Generating charts repo index...'
    
    local indexOutput=$(./cr index -o "$owner" -r "$repo" -c "$charts_repo_url" -t $token)

    echo "$indexOutput"

    local indexChanged=$(echo "$indexOutput" | grep 'Updating')

    if [ -z $indexChanged ]; then
        echo "Removing index.yaml since the index did not change..."
        if [ -d ".cr-index/index.yaml" ]; then rm .cr-index/index.yaml; fi
    fi
}

get_latest_tag() {
    git fetch --tags > /dev/null 2>&1

    if ! git describe --tags --abbrev=0 2> /dev/null; then
        git rev-list --max-parents=0 --first-parent HEAD
    fi
}

filter_charts() {
    while read -r chart; do
        [[ ! -d "$chart" ]] && continue
        local file="$chart/Chart.yaml"
        if [[ -f "$file" ]]; then
            echo "$chart"
        else
           echo "WARNING: $file is missing, assuming that '$chart' is not a Helm chart. Skipping." 1>&2
        fi
    done
}

get_changed_charts() {
    local commit="$1"

    local changed_files=$(git diff --find-renames --name-only "$commit" -- "$charts_dir")

    local depth=$(( $(tr "/" "\n" <<< "$charts_dir" | sed '/^\(\.\)*$/d' | wc -l) + 1 ))
    local fields="1-${depth}"

    cut -d '/' -f "$fields" <<< "$changed_files" | uniq | filter_charts
}

main "$@"
