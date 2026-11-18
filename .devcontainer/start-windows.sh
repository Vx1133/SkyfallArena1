#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_PATH="${LOCAL_WORKSPACE_FOLDER:-$PWD}"
WINDOWS_DATA="${WORKSPACE_PATH}/.windows-data"
mkdir -p "$WINDOWS_DATA"

# Wait briefly for the Codespaces Docker socket to become available.
for attempt in {1..15}; do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not available yet. Re-run: bash .devcontainer/start-windows.sh"
  exit 0
fi

if docker container inspect roblox-windows >/dev/null 2>&1; then
  docker start roblox-windows >/dev/null
  echo "Existing Windows 11 desktop started. Open forwarded port 8006."
  exit 0
fi

COMMON_ARGS=(
  --detach
  --name roblox-windows
  --restart unless-stopped
  --publish 8006:8006
  --volume "${WINDOWS_DATA}:/storage"
  --cap-add NET_ADMIN
  --stop-timeout 120
  --env VERSION=11
  --env CPU_CORES=4
  --env RAM_SIZE=8G
  --env DISK_SIZE=32G
  --env DISK_FMT=qcow2
  --env WIDTH=1280
  --env HEIGHT=720
  --env LANGUAGE=English
)

# Use hardware virtualization when the Codespaces host exposes KVM.
if docker run "${COMMON_ARGS[@]}" --device=/dev/kvm --device=/dev/net/tun dockurr/windows; then
  echo "Windows 11 is starting with KVM acceleration. Open forwarded port 8006."
  exit 0
fi

# Fall back to software emulation if KVM devices are unavailable.
docker rm -f roblox-windows >/dev/null 2>&1 || true
docker run "${COMMON_ARGS[@]}" --env KVM=N dockurr/windows
echo "Windows 11 is starting without KVM acceleration. Open forwarded port 8006."
