#!/usr/bin/env bash
set -euo pipefail

# Official Huawei Cloud archive. Update version, URL and published digest together.
toolchain_version=5.1.0.840
toolchain_sha256=1dcefa4741dc289277560b2802040e0c45b433898d8db453d711d5376e0478f1
toolchain_url="https://repo.huaweicloud.com/harmonyos/ohpm/5.1.0/commandline-tools-linux-x64-${toolchain_version}.zip"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'This installer requires Linux x86_64. Use the matching DevEco tools for local builds.' >&2
  exit 1
fi

sdk_parent="$(mktemp -d "${RUNNER_TEMP:?}/library-hm-harmonyos.XXXXXX")"
archive="${sdk_parent}/command-line-tools.zip"
curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
  --connect-timeout 20 --max-time 1200 --retry 3 --output "$archive" "$toolchain_url"
printf '%s  %s\n' "$toolchain_sha256" "$archive" | sha256sum --check --status
unzip -q "$archive" -d "$sdk_parent"
rm -- "$archive"

toolchain_root="${sdk_parent}/command-line-tools"
for tool in ohpm hvigorw codelinter; do
  test -f "${toolchain_root}/bin/${tool}"
done
test -x "${toolchain_root}/tool/node/bin/node"
test -f "${toolchain_root}/sdk/default/sdk-pkg.json"
printf '%s\n' "${toolchain_root}/bin" "${toolchain_root}/tool/node/bin" >> "${GITHUB_PATH:?}"
printf 'DEVECO_SDK_HOME=%s\nHOS_SDK_HOME=%s\n' \
  "${toolchain_root}/sdk" "${toolchain_root}/sdk" >> "${GITHUB_ENV:?}"
echo "Verified HarmonyOS Command Line Tools ${toolchain_version}"
