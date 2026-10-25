#!/bin/bash
set -e

: "${AZP_URL:?missing AZP_URL}"

# Prefer a mounted secret file; fall back to the env var
if [ -z "${AZP_TOKEN_FILE}" ]; then
  : "${AZP_TOKEN:?missing AZP_TOKEN or AZP_TOKEN_FILE}"
  AZP_TOKEN_FILE=/azp/.token
  echo -n "${AZP_TOKEN}" > "${AZP_TOKEN_FILE}"
fi
unset AZP_TOKEN
export VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE"

case "$(uname -m)" in
  aarch64) platform=linux-arm64 ;;
  *) platform=linux-x64 ;;
esac

if [ ! -e ./config.sh ]; then
  echo "Downloading latest ${platform} agent..."
  url=$(curl -fLsS -u "user:$(cat "${AZP_TOKEN_FILE}")" \
    "${AZP_URL}/_apis/distributedtask/packages/agent?platform=${platform}&top=1" \
    | jq -r '.value[0].downloadUrl')
  [ -n "${url}" ] && [ "${url}" != null ] || { echo >&2 "error: no agent package found; check AZP_URL and token"; exit 1; }
  curl -fLsS "${url}" | tar -xz
fi

source ./env.sh

cleanup() {
  trap "" EXIT
  # Removal fails while a job is running, so retry until it finishes
  until ./config.sh remove --unattended --auth PAT --token "$(cat "${AZP_TOKEN_FILE}")"; do
    echo "Retrying removal in 30s..."
    sleep 30
  done
}
trap "cleanup; exit 0" EXIT
trap "cleanup; exit 130" INT
trap "cleanup; exit 143" TERM

./config.sh --unattended \
  --agent "${AZP_AGENT_NAME:-$(hostname)}" \
  --url "${AZP_URL}" \
  --auth PAT \
  --token "$(cat "${AZP_TOKEN_FILE}")" \
  --pool "${AZP_POOL:-Default}" \
  --work "${AZP_WORK:-_work}" \
  --replace \
  --acceptTeeEula & wait $!

# Pass --once to exit after a single job
./run.sh "$@" & wait $!
