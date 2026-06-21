#!/usr/bin/env -S bash --noprofile --norc -euo pipefail

if [ ! -z "${1:-}" ]; then # Set project from first input
    PROJECT_FILE="$1"
elif [ ! -z "${PROJECT_FILE:-}" ] && [ ! -f "$PROJECT_FILE" ]; then
    echo "Project file not found" >&2
    exit 1
elif [ ! -z "$PROJECT_FILE" ]; then # Set project from PROJECT_FILE env var
    :
else # Use modrinth.yaml/yml in the current directory as the project file
    PROJECT_FILE=$(find . -type f -maxdepth 1 \( -name 'modrinth.yaml' -o -name 'modrinth.yml' \))
fi

LOCK_FILE="./modrinth.lock.txt"

API='https://api.modrinth.com/v2'
USER_AGENT='seanchristians/modrinth-project-lock/1.1.0'

CURLOPTS=(
--location --compressed
--retry 5 --retry-all-errors --fail
--silent --show-error
--user-agent "$USER_AGENT"
)

# The security delay reduces supply-chain attack risk by filtering out
# versions published within the last two days.
SECURITY_DELAY=${SECURITY_DELAY:-172800}

DEFAULT_GAME_VERSION=$(yq '.minecraft_version' $PROJECT_FILE)
DEFAULT_LOADER=$(yq '.loader' $PROJECT_FILE)

MODRINTH_CACHE=$(mktemp)
PROJECT_CACHE=$(mktemp)

function delete_caches {
    rm "$MODRINTH_CACHE" "$PROJECT_CACHE"
}

trap delete_caches EXIT

function get_project_latest_version {
    local GAME_VERSION=$1
    local LOADER=$2 # Only the loaders supported by itzg/docker-minecraft-server: datapack, fabric, forge, paper
    local PROJECT_SLUG=$3
    local VERSION_TYPE=$4 # release, beta, alpha

    if [ "$LOADER" = "vanilla" ]; then
        LOADER="datapack"
    fi

    curl ${CURLOPTS[@]} --get "$API/project/$PROJECT_SLUG/version" \
        --header 'Accept: application/json' \
        --data-urlencode "loaders=[\"$LOADER\"]"\
        --data-urlencode "game_versions=[\"$GAME_VERSION\"]" \
        --data-urlencode "include_changelog=false" \
        --output "$MODRINTH_CACHE"

    # * Note about the 'gsub' command *: dates from Modrinth include fractional
    # seconds, but jq's implementation of 'fromdateiso8601' doesn't support
    # this. Normally we could use strptime() with the %f substitution, but
    # macOS doesn't support that.
    jq --raw-output \
        --arg versionType "$VERSION_TYPE" \
        --argjson securityDelay $SECURITY_DELAY \
        'map(select(
            .version_type == $versionType
            and .status == "listed"
            and (.date_published | gsub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) < (now - $securityDelay)
        ))
        | sort_by(.date_published) | last
        | "\(.project_id):\(.id)"' \
        "$MODRINTH_CACHE"
}

# Convert the YAML representation to JSON and add default values for game_version, loader, and version_type.
yq ".projects[] |= {
\"release_type\": \"release\",
\"prefix\": \"$DEFAULT_LOADER\",
\"game_version\": \"$DEFAULT_GAME_VERSION\"
} + . | .projects" -o json "$PROJECT_FILE" > "$PROJECT_CACHE"

TEMP_LOCK_FILE=$(mktemp)

while IFS= read -r PROJECT_JSON; do
    GAME_VERSION=$(jq -r '.game_version' <<< "$PROJECT_JSON")
    LOADER=$(jq -r '.prefix' <<< "$PROJECT_JSON")
    PROJECT_ID=$(jq -r '.id' <<< "$PROJECT_JSON")
    VERSION_TYPE=$(jq -r '.release_type' <<< "$PROJECT_JSON")

    PROJECT_STRING=""

    if [ "$LOADER" != "$DEFAULT_LOADER" ]; then
        PROJECT_STRING+="$LOADER:"
    fi

    PROJECT_STRING+=$(get_project_latest_version "$GAME_VERSION" "$LOADER" "$PROJECT_ID" "$VERSION_TYPE")

    echo "$PROJECT_STRING" >> "$TEMP_LOCK_FILE"
done < <(jq -c '.[]' $PROJECT_CACHE)

mv "$TEMP_LOCK_FILE" "$LOCK_FILE"
