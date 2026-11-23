#!/usr/bin/env bash

set -euo pipefail

# The files installed by the script conform to the Filesystem Hierarchy Standard:
# https://wiki.linuxfoundation.org/lsb/fhs

# The URL of the script project is:
# https://github.com/XTLS/Xray-install

# The URL of the script is:
# https://github.com/XTLS/Xray-install/raw/main/install-release.sh

# If the script executes incorrectly, go to:
# https://github.com/XTLS/Xray-install/issues

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export DAT_PATH='/usr/local/share/xray'
DAT_PATH=${DAT_PATH:-/usr/local/share/xray}

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export JSON_PATH='/usr/local/etc/xray'
JSON_PATH=${JSON_PATH:-/usr/local/etc/xray}

# Set this variable only if you are starting xray with multiple configuration files:
# export JSONS_PATH='/usr/local/etc/xray'
JSONS_PATH=${JSONS_PATH:-}

# Set this variable only if you want this script to check all the systemd unit file:
# export check_all_service_files='yes'
check_all_service_files=${check_all_service_files:-}

# Gobal verbals

if [[ -f '/etc/systemd/system/xray.service' ]] && [[ -f '/usr/local/bin/xray' ]]; then
  XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT=1
else
  XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT=0
fi

# Xray current version
CURRENT_VERSION=''

# Xray latest release version
RELEASE_LATEST=''

# Xray latest prerelease/release version
PRE_RELEASE_LATEST=''

# Xray version will be installed
INSTALL_VERSION=''

# install
INSTALL='0'

# update-geodata
UPDATE_GEODATA='0'

# remove
REMOVE='0'

# help
HELP='0'

# check
CHECK='0'

# --force
FORCE='0'

# --beta
BETA='0'

# --without-geodata
NO_GEODATA='0'

# --without-logfiles
NO_LOGFILES='0'

# --logrotate
LOGROTATE='0'

# --no-update-service
N_UP_SERVICE='0'

# --reinstall
REINSTALL='0'

# --version ?
SPECIFIED_VERSION=''

# --local ?
LOCAL_FILE=''

# --geoip / --geosite ?
LOCAL_GEOIP=''
LOCAL_GEOSITE=''

# --proxy ?
PROXY=''

# --purge
PURGE='0'

# --manually-restart-later
NO_RESTART='0'

# Installation status
GEODATA='0'
CONFIG_NEW='0'
CONFDIR='0'
LOG='0'
LOGROTATE_FIN='0'
LOGROTATE_DIR='0'
SYSTEMD='0'
XRAY_RUNNING='0'

TMP_PATHS=()

cleanup() {
  if [[ "${#TMP_PATHS[@]}" -gt '0' ]]; then
    "rm" -rf -- "${TMP_PATHS[@]}" || :
  fi
}

trap cleanup EXIT

curl() {
  $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
}

systemd_cat_config() {
  if systemd-analyze --help | grep -w 'cat-config' >/dev/null; then
    systemd-analyze --no-pager cat-config "$@"
    echo
  else
    echo "${aoi}~~~~~~~~~~~~~~~~"
    cat "$@" "$1".d/*
    echo "${aoi}~~~~~~~~~~~~~~~~"
    echo "${red}warning: ${green}The systemd version on the current operating system is too low."
    echo "${red}warning: ${green}Please consider to upgrade the systemd or the operating system.${reset}"
    echo
  fi
}

check_if_running_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  else
    echo "error: You must run this script as root!"
    return 1
  fi
}

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" != 'Linux' ]]; then
    echo "error: This operating system is not supported."
    return 1
  fi
  case "$(uname -m)" in
  'i386' | 'i686')
    MACHINE='32'
    ;;
  'amd64' | 'x86_64')
    MACHINE='64'
    ;;
  'armv5tel')
    MACHINE='arm32-v5'
    ;;
  'armv6l')
    MACHINE='arm32-v6'
    grep Features /proc/cpuinfo | grep -w 'vfp' >/dev/null || MACHINE='arm32-v5'
    ;;
  'armv7' | 'armv7l')
    MACHINE='arm32-v7a'
    grep Features /proc/cpuinfo | grep -w 'vfp' >/dev/null || MACHINE='arm32-v5'
    ;;
  'armv8' | 'aarch64')
    MACHINE='arm64-v8a'
    ;;
  'mips')
    MACHINE='mips32'
    ;;
  'mipsle')
    MACHINE='mips32le'
    ;;
  'mips64')
    MACHINE='mips64'
    lscpu | grep "Little Endian" >/dev/null && MACHINE='mips64le'
    ;;
  'mips64le')
    MACHINE='mips64le'
    ;;
  'ppc64')
    MACHINE='ppc64'
    ;;
  'ppc64le')
    MACHINE='ppc64le'
    ;;
  'riscv64')
    MACHINE='riscv64'
    ;;
  's390x')
    MACHINE='s390x'
    ;;
  *)
    echo "error: The architecture is not supported."
    return 1
    ;;
  esac
  if [[ ! -f '/etc/os-release' ]]; then
    echo "error: Don't use outdated Linux distributions."
    return 1
  fi
  # Do not combine this judgment condition with the following judgment condition.
  ## Be aware of Linux distribution like Gentoo, which kernel supports switch between Systemd and OpenRC.
  if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
    true
  elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
    true
  else
    echo "error: Only Linux distributions using systemd are supported."
    return 1
  fi
  if [[ "$(type -P apt)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
    PACKAGE_MANAGEMENT_REMOVE='apt purge'
    package_provide_tput='ncurses-bin'
  elif [[ "$(type -P dnf)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
    PACKAGE_MANAGEMENT_REMOVE='dnf remove'
    package_provide_tput='ncurses'
  elif [[ "$(type -P yum)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='yum -y install'
    PACKAGE_MANAGEMENT_REMOVE='yum remove'
    package_provide_tput='ncurses'
  elif [[ "$(type -P zypper)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
    PACKAGE_MANAGEMENT_REMOVE='zypper remove'
    package_provide_tput='ncurses-utils'
  elif [[ "$(type -P pacman)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='pacman -Syy --noconfirm'
    PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
    package_provide_tput='ncurses'
  elif [[ "$(type -P emerge)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='emerge -qv'
    PACKAGE_MANAGEMENT_REMOVE='emerge -Cv'
    package_provide_tput='ncurses'
  else
    echo "error: The script does not support the package manager in this operating system."
    return 1
  fi
}

## Demo function for processing parameters
judgment_parameters() {
  local local_install='0'
  local temp_version='0'
  while [[ "$#" -gt '0' ]]; do
    case "$1" in
    'install')
      INSTALL='1'
      ;;
    'update-geodata')
      UPDATE_GEODATA='1'
      ;;
    'remove')
      REMOVE='1'
      ;;
    'help')
      HELP='1'
      ;;
    'check')
      CHECK='1'
      ;;
    '--without-geodata')
      NO_GEODATA='1'
      ;;
    '--without-logfiles')
      NO_LOGFILES='1'
      ;;
    '--purge')
      PURGE='1'
      ;;
    '--version')
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "error: Please specify the correct version."
        return 1
      fi
      temp_version='1'
      SPECIFIED_VERSION="$2"
      shift
      ;;
    '-f' | '--force')
      FORCE='1'
      ;;
    '--beta')
      BETA='1'
      ;;
    '-l' | '--local')
      local_install='1'
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "error: Please specify a local Xray zip file after --local."
        return 1
      fi
      LOCAL_FILE="$2"
      shift
      ;;
    '--geoip' | '--geosite')
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "error: Please specify a local geodata file after $1."
        return 1
      fi
      if [[ "$1" == '--geoip' ]]; then
        LOCAL_GEOIP="$2"
      else
        LOCAL_GEOSITE="$2"
      fi
      shift
      ;;
    '-p' | '--proxy')
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "error: Please specify the proxy server address."
        return 1
      fi
      PROXY="$2"
      shift
      ;;
    '--reinstall')
      REINSTALL='1'
      ;;
    '--no-update-service')
      N_UP_SERVICE='1'
      ;;
    '--logrotate')
      if [[ ! "${2:-}" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$ ]]; then
        echo "error: Wrong format of time, it should be in the format of 12:34:56, under 10:00:00 should be start with 0, e.g. 01:23:45."
        return 1
      fi
      LOGROTATE='1'
      LOGROTATE_TIME="$2"
      shift
      ;;
    '--manually-restart-later')
      NO_RESTART='1'
      ;;
    *)
      echo "$0: unknown option -- -"
      return 1
      ;;
    esac
    shift
  done
  if ((INSTALL + UPDATE_GEODATA + HELP + CHECK + REMOVE == 0)); then
    INSTALL='1'
  elif ((INSTALL + UPDATE_GEODATA + HELP + CHECK + REMOVE > 1)); then
    echo 'You can only choose one action.'
    return 1
  fi
  if [[ "$local_install" -eq '1' && "$INSTALL" -ne '1' ]]; then
    echo 'error: --local can only be used with install.'
    return 1
  fi
  if [[ "$INSTALL" -eq '1' ]] && ((temp_version + local_install + REINSTALL + BETA > 1)); then
    echo "--version,--reinstall,--beta and --local can't be used together."
    return 1
  fi
  if [[ -n "$LOCAL_GEOIP" || -n "$LOCAL_GEOSITE" ]]; then
    if [[ -z "$LOCAL_FILE" ]]; then
      echo 'error: --geoip and --geosite can only be used with --local.'
      return 1
    fi
    if [[ "$NO_GEODATA" -eq '1' ]]; then
      echo 'error: --geoip and --geosite cannot be used with --without-geodata.'
      return 1
    fi
  fi
  if [[ "$INSTALL" -eq '1' ]] && ((FORCE + NO_RESTART > 1)); then
    echo "-f/--force and --manually-restart-later can't be used together."
    return 1
  fi
  if [[ "$INSTALL" -eq '1' ]] && ((REINSTALL + NO_RESTART > 1)); then
    echo "--reinstall and --manually-restart-later can't be used together."
    return 1
  fi
}

verify_local_archive() {
  local digest_file="${LOCAL_FILE}.dgst" checksum local_sum
  if [ ! -f "$LOCAL_FILE" ] || [ ! -r "$LOCAL_FILE" ]; then
    echo "error: Local Xray archive is not a readable file: $LOCAL_FILE"
    return 1
  fi
  if [ ! -e "$digest_file" ] && [ ! -L "$digest_file" ]; then
    echo "warning: No local verification file found: $digest_file; continuing without SHA256 verification."
    return 0
  fi
  if [ ! -f "$digest_file" ] || [ ! -r "$digest_file" ]; then
    echo "error: Local verification file is not readable: $digest_file"
    return 1
  fi
  checksum="$(awk -F '=' '/^[[:space:]]*SHA(2-)?256[[:space:]]*=/ {
    if (NF != 2) { print "invalid"; next }
    value = $2
    sub(/^[[:space:]]*/, "", value)
    sub(/[[:space:]]*$/, "", value)
    print tolower(value)
  }' "$digest_file")"
  case "$checksum" in
  '' | *[!0-9a-f]*)
    echo "error: Missing or invalid SHA256 digest in $digest_file"
    return 1
    ;;
  esac
  if [ "${#checksum}" -ne 64 ]; then
    echo "error: Missing or invalid SHA256 digest in $digest_file"
    return 1
  fi
  if ! local_sum="$(sha256sum "$LOCAL_FILE")"; then
    echo "error: Could not calculate SHA256 for $LOCAL_FILE"
    return 1
  fi
  local_sum="${local_sum%% *}"
  if [ "$checksum" != "$local_sum" ]; then
    echo "error: SHA256 check failed for $LOCAL_FILE"
    return 1
  fi
  echo 'info: Local Xray archive passed SHA256 verification.'
}

check_local_xray_version() {
  if ! chmod u+x "$TMP_DIRECTORY/xray" || ! "$TMP_DIRECTORY/xray" -version >/dev/null 2>&1; then
    echo 'error: Local xray binary cannot run. Please check its architecture and format.'
    return 1
  fi
}

check_local_geodata() {
  local file
  for file in "$LOCAL_GEOIP" "$LOCAL_GEOSITE"; do
    [[ -n "$file" ]] || continue
    if [[ ! -f "$file" || ! -r "$file" || ! -s "$file" ]]; then
      echo "error: Local geodata must be a readable, non-empty file: $file"
      return 1
    fi
  done
}

prepare_local_geodata() {
  # Preserve the existing switches that disable geodata installation.
  if [[ "$NO_GEODATA" -eq '1' || -f "${DAT_PATH}/.undat" ]]; then
    return 0
  fi
  local file
  if [[ -n "$LOCAL_GEOIP" ]]; then
    cp -- "$LOCAL_GEOIP" "${TMP_DIRECTORY}/geoip.dat"
  fi
  if [[ -n "$LOCAL_GEOSITE" ]]; then
    cp -- "$LOCAL_GEOSITE" "${TMP_DIRECTORY}/geosite.dat"
  fi
  for file in geoip.dat geosite.dat; do
    if [[ ! -f "${TMP_DIRECTORY}/$file" || ! -r "${TMP_DIRECTORY}/$file" || ! -s "${TMP_DIRECTORY}/$file" ]]; then
      echo "error: Missing, empty or unreadable geodata: $file"
      return 1
    fi
  done
}

install_software() {
  package_name="$1"
  file_to_detect="$2"
  type -P "$file_to_detect" >/dev/null 2>&1 && return
  if ${PACKAGE_MANAGEMENT_INSTALL} "$package_name" >/dev/null 2>&1; then
    echo "info: $package_name is installed."
  else
    echo "error: Installation of $package_name failed, please check your network."
    exit 1
  fi
}

get_current_version() {
  # Get the CURRENT_VERSION
  if [[ -f '/usr/local/bin/xray' ]]; then
    CURRENT_VERSION="$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')"
    CURRENT_VERSION="v${CURRENT_VERSION#v}"
  else
    CURRENT_VERSION=""
  fi
}

get_latest_version() {
  # Get Xray latest release version number
  local tmp_file
  tmp_file="$(mktemp)"
  TMP_PATHS+=("$tmp_file")
  local url='https://api.github.com/repos/XTLS/Xray-core/releases/latest'
  if curl -x "${PROXY}" -sSfLo "$tmp_file" -H "Accept: application/vnd.github.v3+json" "$url"; then
    echo "get release list success"
  else
    "rm" "$tmp_file"
    echo 'error: Failed to get release list, please check your network.'
    exit 1
  fi
  RELEASE_LATEST="$(sed 'y/,/\n/' "$tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}')" || RELEASE_LATEST=''
  if [[ -z "$RELEASE_LATEST" ]]; then
    if grep -q "API rate limit exceeded" "$tmp_file"; then
      echo "error: github API rate limit exceeded"
    else
      echo "error: Failed to get the latest release version."
      echo "Welcome bug report:https://github.com/XTLS/Xray-install/issues"
    fi
    "rm" "$tmp_file"
    exit 1
  fi
  "rm" "$tmp_file"
  RELEASE_LATEST="v${RELEASE_LATEST#v}"
  url='https://api.github.com/repos/XTLS/Xray-core/releases'
  if curl -x "${PROXY}" -sSfLo "$tmp_file" -H "Accept: application/vnd.github.v3+json" "$url"; then
    echo "get release list success"
  else
    "rm" "$tmp_file"
    echo 'error: Failed to get release list, please check your network.'
    exit 1
  fi
  local releases_list
  readarray -t releases_list < <(sed 'y/,/\n/' "$tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}')
  if [[ "${#releases_list[@]}" -eq 0 ]]; then
    if grep -q "API rate limit exceeded" "$tmp_file"; then
      echo "error: github API rate limit exceeded"
    else
      echo "error: Failed to get the latest release version."
      echo "Welcome bug report:https://github.com/XTLS/Xray-install/issues"
    fi
    "rm" "$tmp_file"
    exit 1
  fi
  local i url_zip
  for i in "${!releases_list[@]}"; do
    releases_list["$i"]="v${releases_list[$i]#v}"
    url_zip="https://github.com/XTLS/Xray-core/releases/download/${releases_list[$i]}/Xray-linux-$MACHINE.zip"
    if grep -q "$url_zip" "$tmp_file"; then
      PRE_RELEASE_LATEST="${releases_list[$i]}"
      break
    fi
  done
  "rm" "$tmp_file"
}

version_gt() {
  test "$(echo -e "$1\\n$2" | sort -V | head -n 1)" != "$1"
}

download_xray() {
  local DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/${INSTALL_VERSION}/Xray-linux-${MACHINE}.zip"
  echo "Downloading Xray archive: $DOWNLOAD_LINK"
  if curl -f -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
    echo "ok."
  else
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  echo "Downloading verification file for Xray archive: ${DOWNLOAD_LINK}.dgst"
  if curl -f -x "${PROXY}" -sSR -H 'Cache-Control: no-cache' -o "${ZIP_FILE}.dgst" "${DOWNLOAD_LINK}.dgst"; then
    echo "ok."
  else
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  if grep 'Not Found' "${ZIP_FILE}.dgst"; then
    echo 'error: This version does not support verification. Please replace with another version.'
    return 1
  fi

  # Verification of Xray archive
  CHECKSUM=$(awk -F '= ' '/256=/ {print $2}' "${ZIP_FILE}.dgst")
  LOCALSUM=$(sha256sum "$ZIP_FILE" | awk '{printf $1}')
  if [[ "$CHECKSUM" != "$LOCALSUM" ]]; then
    echo 'error: SHA256 check failed! Please check your network or try again.'
    return 1
  fi
}

decompression() {
  if ! unzip -q "$1" -d "$TMP_DIRECTORY"; then
    echo 'error: Xray decompression failed.'
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
  fi
  echo "info: Extract the Xray package to $TMP_DIRECTORY and prepare it for installation."
}

create_xray_user() {
  if id -u xray >/dev/null 2>&1; then
    printf '%s\n' \
      "WARNING: The 'xray' user already exists and will be reused to run Xray." \
      'WARNING: Ensure this account is dedicated to Xray; it will own Xray logs and geodata.' >&2
  fi
  systemd-sysusers - <<'EOF'
u xray - "Xray" /var/empty
EOF
  if [[ "$(id -u xray)" -eq '0' || "$(id -g xray)" -eq '0' ]]; then
    echo 'error: The xray account must have a non-root user and group.'
    exit 1
  fi
}

install_file() {
  NAME="$1"
  if [[ "$NAME" == 'xray' ]]; then
    install -m 755 -o 0 -g 0 "${TMP_DIRECTORY}/$NAME" "/usr/local/bin/$NAME"
  elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
    install -m 644 -o xray -g xray "${TMP_DIRECTORY}/$NAME" "${DAT_PATH}/$NAME"
  fi
}

install_geodata_dir() {
  install -d -m 755 -o xray -g xray "$DAT_PATH"
}

install_xray() {
  # Install Xray binary to /usr/local/bin/ and $DAT_PATH
  install_file xray
  if [[ -d "$DAT_PATH" ]]; then
    chown -hR xray:xray "$DAT_PATH"
  fi
  # Skip archive geodata when --without-geodata or $DAT_PATH/.undat is present.
  if [[ "$NO_GEODATA" -eq '0' ]] && [[ ! -f "${DAT_PATH}/.undat" ]]; then
    install_geodata_dir
    install_file geoip.dat
    install_file geosite.dat
    GEODATA='1'
  fi

  # Install Xray configuration file to $JSON_PATH
  # shellcheck disable=SC2153
  if [[ -z "$JSONS_PATH" ]] && [[ ! -d "$JSON_PATH" ]]; then
    install -d -m 750 -o 0 -g xray "$JSON_PATH"
    install -m 640 -o 0 -g xray /dev/null "${JSON_PATH}/config.json"
    echo "{}" >"${JSON_PATH}/config.json"
    CONFIG_NEW='1'
  fi

  # Install Xray configuration file to $JSONS_PATH
  if [[ -n "$JSONS_PATH" ]] && [[ ! -d "$JSONS_PATH" ]]; then
    install -d -m 750 -o 0 -g xray "$JSONS_PATH"
    for BASE in 00_log 01_api 02_dns 03_routing 04_policy 05_inbounds 06_outbounds 07_stats 08_fakedns 09_metrics 10_observatory 11_geodata 12_env 99_version; do
      install -m 640 -o 0 -g xray /dev/null "${JSONS_PATH}/${BASE}.json"
      echo '{}' >"${JSONS_PATH}/${BASE}.json"
    done
    CONFDIR='1'
  fi

  # Used to store Xray log files
  if [[ "$NO_LOGFILES" -eq '0' ]]; then
    if [[ ! -d '/var/log/xray/' ]]; then
      install -d -m 700 -o xray -g xray /var/log/xray/
      LOG='1'
    else
      chown -hR xray:xray /var/log/xray/
      chmod 700 /var/log/xray/
    fi
  fi
}

install_startup_service_file() {
  mkdir -p '/etc/systemd/system/xray.service.d'
  mkdir -p '/etc/systemd/system/xray@.service.d/'
  cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://xtls.github.io/
After=network.target nss-lookup.target

[Service]
User=xray
Group=xray
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
UMask=0077
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
RuntimeDirectory=xray
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF
  cat >/etc/systemd/system/xray@.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://xtls.github.io/
After=network.target nss-lookup.target

[Service]
User=xray
Group=xray
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
UMask=0077
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/%i.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
RuntimeDirectory=xray-%i
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF
  chmod 644 /etc/systemd/system/xray.service /etc/systemd/system/xray@.service
  if [[ -n "$JSONS_PATH" ]]; then
    "rm" -f '/etc/systemd/system/xray.service.d/10-donot_touch_single_conf.conf' \
      '/etc/systemd/system/xray@.service.d/10-donot_touch_single_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=/usr/local/bin/xray run -confdir $JSONS_PATH" > \
      '/etc/systemd/system/xray.service.d/10-donot_touch_multi_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=/usr/local/bin/xray run -confdir ${JSONS_PATH%/}/%i/" > \
      '/etc/systemd/system/xray@.service.d/10-donot_touch_multi_conf.conf'
  else
    "rm" -f '/etc/systemd/system/xray.service.d/10-donot_touch_multi_conf.conf' \
      '/etc/systemd/system/xray@.service.d/10-donot_touch_multi_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=/usr/local/bin/xray run -config ${JSON_PATH}/config.json" > \
      '/etc/systemd/system/xray.service.d/10-donot_touch_single_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=/usr/local/bin/xray run -config ${JSON_PATH}/%i.json" > \
      '/etc/systemd/system/xray@.service.d/10-donot_touch_single_conf.conf'
  fi
  echo "info: Systemd service files have been installed successfully!"
  echo "${red}warning: ${green}The following are the actual parameters for the xray service startup."
  echo "${red}warning: ${green}Please make sure the configuration file path is correctly set.${reset}"
  systemd_cat_config /etc/systemd/system/xray.service
  # shellcheck disable=SC2154
  if [[ "${check_all_service_files:0:1}" = 'y' ]]; then
    echo
    echo
    systemd_cat_config /etc/systemd/system/xray@.service
  fi
  systemctl daemon-reload
  SYSTEMD='1'
}

start_xray() {
  if [[ -f '/etc/systemd/system/xray.service' ]]; then
    systemctl start "${XRAY_CUSTOMIZE[@]:-xray}"
    sleep 1s
    local xray_daemon
    for xray_daemon in "${XRAY_CUSTOMIZE[@]:-xray}"; do
      if ! systemctl -q is-active "$xray_daemon"; then
        echo 'error: Failed to start Xray service.'
        exit 1
      fi
    done
    echo 'info: Start the Xray service.'
  fi
}

stop_xray() {
  local xray_units
  xray_units="$(systemctl list-units | awk '$1 == "xray.service" || $1 ~ /^xray@.*\.service$/ {print $1}')"
  XRAY_CUSTOMIZE=()
  if [[ -n "$xray_units" ]]; then
    readarray -t XRAY_CUSTOMIZE <<<"$xray_units"
  fi
  if ! systemctl stop "${XRAY_CUSTOMIZE[@]:-xray.service}"; then
    echo 'error: Stopping the Xray service failed.'
    exit 1
  fi
  echo 'info: Stop the Xray service.'
}

install_with_logrotate() {
  install_software 'logrotate' 'logrotate'
  if [[ -z "${LOGROTATE_TIME:-}" ]]; then
    LOGROTATE_TIME="00:00:00"
  fi
  cat <<EOF >/etc/systemd/system/logrotate@.service
[Unit]
Description=Rotate log files
Documentation=man:logrotate(8)

[Service]
Type=oneshot
ExecStart=/usr/sbin/logrotate /etc/logrotate.d/%i
EOF
  cat <<EOF >/etc/systemd/system/logrotate@.timer
[Unit]
Description=Run logrotate for %i logs

[Timer]
OnCalendar=*-*-* $LOGROTATE_TIME
Persistent=true

[Install]
WantedBy=timers.target
EOF
  if [[ ! -d '/etc/logrotate.d/' ]]; then
    LOGROTATE_DIR='1'
  fi
  install -d -m 755 -o 0 -g 0 /etc/logrotate.d/
  cat <<EOF >/etc/logrotate.d/xray
/var/log/xray/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
  LOGROTATE_FIN='1'
}

update_geodata() {
  create_xray_user
  download_geodata() {
    if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "${dir_tmp}/${2}" "${1}"; then
      echo 'error: Download failed! Please check your network or try again.'
      exit 1
    fi
    if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "${dir_tmp}/${2}.sha256sum" "${1}.sha256sum"; then
      echo 'error: Download failed! Please check your network or try again.'
      exit 1
    fi
  }
  local file_ip='geoip-full.dat'
  local file_site='geosite-expand.dat'
  local download_link_geoip="https://github.com/XTLS/Xray-rules-dat/releases/latest/download/${file_ip}"
  local download_link_geosite="https://github.com/XTLS/Xray-rules-dat/releases/latest/download/${file_site}"
  local dir_tmp
  dir_tmp="$(mktemp -d)"
  TMP_PATHS+=("$dir_tmp")
  [[ "$XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT" -eq '0' ]] && echo "warning: Xray was not installed"
  download_geodata "$download_link_geoip" "$file_ip"
  download_geodata "$download_link_geosite" "$file_site"
  cd "${dir_tmp}" || exit
  for i in "${dir_tmp}"/*.sha256sum; do
    if ! sha256sum -c "${i}"; then
      echo 'error: Check failed! Please check your network or try again.'
      exit 1
    fi
  done
  cd - >/dev/null || exit 1
  install_geodata_dir
  install -m 644 -o xray -g xray "${dir_tmp}/${file_site}" "${DAT_PATH}/geosite.dat"
  install -m 644 -o xray -g xray "${dir_tmp}/${file_ip}" "${DAT_PATH}/geoip.dat"
  rm -r "${dir_tmp}"
  exit 0
}

check_update() {
  if [[ "$XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT" -eq '1' ]]; then
    get_current_version
    echo "info: The current version of Xray is ${CURRENT_VERSION}."
  else
    echo 'warning: Xray is not installed.'
  fi
  get_latest_version
  echo "info: The latest release version of Xray is ${RELEASE_LATEST}."
  echo "info: The latest pre-release/release version of Xray is ${PRE_RELEASE_LATEST}."
  exit 0
}

remove_xray() {
  if systemctl list-unit-files | grep -w 'xray' >/dev/null; then
    if [[ -n "$(pidof xray)" ]]; then
      stop_xray
    fi
    local delete_files=('/usr/local/bin/xray' '/etc/systemd/system/xray.service' '/etc/systemd/system/xray@.service' '/etc/systemd/system/xray.service.d' '/etc/systemd/system/xray@.service.d')
    [[ -d "$DAT_PATH" ]] && delete_files+=("$DAT_PATH")
    [[ -f '/etc/logrotate.d/xray' ]] && delete_files+=('/etc/logrotate.d/xray')
    if [[ "$PURGE" -eq '1' ]]; then
      if [[ -z "$JSONS_PATH" ]]; then
        delete_files+=("$JSON_PATH")
      else
        delete_files+=("$JSONS_PATH")
      fi
      [[ -d '/var/log/xray' ]] && delete_files+=('/var/log/xray')
      [[ -f '/etc/systemd/system/logrotate@.service' ]] && delete_files+=('/etc/systemd/system/logrotate@.service')
      [[ -f '/etc/systemd/system/logrotate@.timer' ]] && delete_files+=('/etc/systemd/system/logrotate@.timer')
    fi
    systemctl disable xray
    if [[ -f '/etc/systemd/system/logrotate@.timer' ]]; then
      if ! systemctl stop logrotate@xray.timer || ! systemctl disable logrotate@xray.timer; then
        echo 'error: Stopping and disabling the logrotate service failed.'
        exit 1
      fi
      echo 'info: Stop and disable the logrotate service.'
    fi
    if ! ("rm" -r "${delete_files[@]}"); then
      echo 'error: Failed to remove Xray.'
      exit 1
    else
      for i in "${!delete_files[@]}"; do
        echo "removed: ${delete_files[$i]}"
      done
      systemctl daemon-reload
      echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl unzip"
      echo 'info: Xray has been removed.'
      if [[ "$PURGE" -eq '0' ]]; then
        echo 'info: If necessary, manually delete the configuration and log files.'
        if [[ -n "$JSONS_PATH" ]]; then
          echo "info: e.g., $JSONS_PATH and /var/log/xray/ ..."
        else
          echo "info: e.g., $JSON_PATH and /var/log/xray/ ..."
        fi
      fi
      exit 0
    fi
  else
    echo 'error: Xray is not installed.'
    exit 1
  fi
}

# Explanation of parameters in the script
show_help() {
  echo "usage: $0 ACTION [OPTION]..."
  echo
  echo 'ACTION:'
  echo '  install                   Install/Update Xray'
  echo '  update-geodata            Download/update GeoIP full and GeoSite expanded only'
  echo '                            Xray bundles GeoIP lite and GeoSite standard; see https://github.com/XTLS/Xray-rules-dat'
  echo '  remove                    Remove Xray'
  echo '  help                      Show help'
  echo '  check                     Check if Xray can be updated'
  echo 'If no action is specified, then install will be selected'
  echo
  echo 'OPTION:'
  echo '  install:'
  echo '    --version                 Install the specified version of Xray, e.g., --version v1.0.0'
  echo '    -f, --force               Force install even though the versions are same'
  echo '    --beta                    Install the pre-release version if it is exist'
  echo '    -l, --local <zip>         Install a local Xray zip without accessing GitHub'
  echo '                              Relative paths use the current working directory; quote paths containing spaces'
  echo '                              Verify <zip>.dgst if present; warn and continue if absent'
  echo '                              Missing tools may be installed from system package repositories'
  echo '                              Uses bundled geodata unless --geoip or --geosite is specified'
  echo '    --geoip <file>            Use a local GeoIP file with --local'
  echo '    --geosite <file>          Use a local GeoSite file with --local'
  echo '    -p, --proxy               Download through a proxy server, e.g., -p http://127.0.0.1:8118 or -p socks5://127.0.0.1:1080'
  echo '    --reinstall               Reinstall current Xray version'
  echo "    --no-update-service       Don't change service files if they are exist"
  echo "    --without-geodata         Don't install/update geoip.dat and geosite.dat"
  echo "    --without-logfiles        Don't install /var/log/xray"
  echo "    --logrotate [time]        Install with logrotate."
  echo "                              [time] need be in the format of 12:34:56, under 10:00:00 should be start with 0, e.g. 01:23:45."
  echo "    --manually-restart-later  ${red}[RISKY]${reset} Service won't be restarted during installation."
  echo "                              ${red}Inconsistency may occur. You must manually restart the service after the installation.${reset}"
  echo '  update-geodata:'
  echo '    -p, --proxy               Download through a proxy server'
  echo '  remove:'
  echo '    --purge                   Remove all the Xray files, include logs, configs, etc'
  echo '  check:'
  echo '    -p, --proxy               Check new version through a proxy server'
  exit 0
}

main() {
  judgment_parameters "$@"
  [[ "$HELP" -eq '1' ]] && show_help
  check_if_running_as_root
  identify_the_operating_system_and_architecture
  if [[ -n "$LOCAL_FILE" ]]; then
    verify_local_archive
    check_local_geodata
  fi

  install_software "$package_provide_tput" 'tput'
  red=$(tput setaf 1 2>/dev/null || true)
  green=$(tput setaf 2 2>/dev/null || true)
  aoi=$(tput setaf 6 2>/dev/null || true)
  reset=$(tput sgr0 2>/dev/null || true)

  # Parameter information
  [[ "$CHECK" -eq '1' ]] && check_update
  [[ "$REMOVE" -eq '1' ]] && remove_xray
  [[ "$UPDATE_GEODATA" -eq '1' ]] && update_geodata

  # Two very important variables
  TMP_DIRECTORY="$(mktemp -d)"
  TMP_PATHS+=("$TMP_DIRECTORY")
  ZIP_FILE="${TMP_DIRECTORY}/Xray-linux-$MACHINE.zip"

  # Local archives never require GitHub; missing tools may use system repositories.
  if [[ -n "$LOCAL_FILE" ]]; then
    install_software 'unzip' 'unzip'
    decompression "$LOCAL_FILE"
    check_local_xray_version
    prepare_local_geodata
  else
    get_current_version
    if [[ "$REINSTALL" -eq '1' ]]; then
      if [[ -z "$CURRENT_VERSION" ]]; then
        echo "error: Xray is not installed"
        exit 1
      fi
      INSTALL_VERSION="$CURRENT_VERSION"
      echo "info: Reinstalling Xray $CURRENT_VERSION"
    elif [[ -n "$SPECIFIED_VERSION" ]]; then
      SPECIFIED_VERSION="v${SPECIFIED_VERSION#v}"
      if [[ "$CURRENT_VERSION" == "$SPECIFIED_VERSION" ]] && [[ "$FORCE" -eq '0' ]]; then
        echo "info: The current version is same as the specified version. The version is ${CURRENT_VERSION}."
        exit 0
      fi
      INSTALL_VERSION="$SPECIFIED_VERSION"
      echo "info: Installing specified Xray version $INSTALL_VERSION for $(uname -m)"
    else
      install_software 'curl' 'curl'
      get_latest_version
      if [[ "$BETA" -eq '0' ]]; then
        INSTALL_VERSION="$RELEASE_LATEST"
      else
        INSTALL_VERSION="$PRE_RELEASE_LATEST"
      fi
      if ! version_gt "$INSTALL_VERSION" "$CURRENT_VERSION" && [[ "$FORCE" -eq '0' ]]; then
        echo "info: No new version. The current version of Xray is ${CURRENT_VERSION}."
        exit 0
      fi
      echo "info: Installing Xray $INSTALL_VERSION for $(uname -m)"
    fi
    install_software 'curl' 'curl'
    install_software 'unzip' 'unzip'
    if ! download_xray; then
      "rm" -r "$TMP_DIRECTORY"
      echo "removed: $TMP_DIRECTORY"
      exit 1
    fi
    decompression "$ZIP_FILE"
  fi

  [[ "$LOGROTATE" -eq '1' ]] && install_with_logrotate

  # Determine if Xray is running
  if systemctl list-unit-files | grep -w 'xray' >/dev/null; then
    if [[ -n "$(pidof xray)" ]]; then
      if [[ "$NO_RESTART" -eq '0' ]]; then
        stop_xray
      fi
      XRAY_RUNNING='1'
    fi
  fi
  create_xray_user
  install_xray
  [[ "$N_UP_SERVICE" -eq '1' && -f '/etc/systemd/system/xray.service' ]] || install_startup_service_file
  echo 'installed: /usr/local/bin/xray'
  # If the file exists, the content output of installing or updating geoip.dat and geosite.dat will not be displayed
  if [[ "$GEODATA" -eq '1' ]]; then
    echo "installed: ${DAT_PATH}/geoip.dat"
    echo "installed: ${DAT_PATH}/geosite.dat"
  fi
  if [[ "$CONFIG_NEW" -eq '1' ]]; then
    echo "installed: ${JSON_PATH}/config.json"
  fi
  if [[ "$CONFDIR" -eq '1' ]]; then
    echo "installed: ${JSON_PATH}/00_log.json"
    echo "installed: ${JSON_PATH}/01_api.json"
    echo "installed: ${JSON_PATH}/02_dns.json"
    echo "installed: ${JSON_PATH}/03_routing.json"
    echo "installed: ${JSON_PATH}/04_policy.json"
    echo "installed: ${JSON_PATH}/05_inbounds.json"
    echo "installed: ${JSON_PATH}/06_outbounds.json"
    echo "installed: ${JSON_PATH}/07_stats.json"
    echo "installed: ${JSON_PATH}/08_fakedns.json"
    echo "installed: ${JSON_PATH}/09_metrics.json"
    echo "installed: ${JSON_PATH}/10_observatory.json"
    echo "installed: ${JSON_PATH}/11_geodata.json"
    echo "installed: ${JSON_PATH}/12_env.json"
    echo "installed: ${JSON_PATH}/99_version.json"
  fi
  if [[ "$LOG" -eq '1' ]]; then
    echo 'installed: /var/log/xray/'
  fi
  if [[ "$LOGROTATE_FIN" -eq '1' ]]; then
    echo 'installed: /etc/systemd/system/logrotate@.service'
    echo 'installed: /etc/systemd/system/logrotate@.timer'
    if [[ "$LOGROTATE_DIR" -eq '1' ]]; then
      echo 'installed: /etc/logrotate.d/'
    fi
    echo 'installed: /etc/logrotate.d/xray'
    systemctl start logrotate@xray.timer
    systemctl enable logrotate@xray.timer
    sleep 1s
    if systemctl -q is-active logrotate@xray.timer; then
      echo "info: Enable and start the logrotate@xray.timer service"
    else
      echo "warning: Failed to enable and start the logrotate@xray.timer service"
    fi
  fi
  if [[ "$SYSTEMD" -eq '1' ]]; then
    echo 'installed: /etc/systemd/system/xray.service'
    echo 'installed: /etc/systemd/system/xray@.service'
  fi
  "rm" -r "$TMP_DIRECTORY"
  echo "removed: $TMP_DIRECTORY"
  get_current_version
  echo "info: Xray $CURRENT_VERSION is installed."
  echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl unzip"
  if [[ "$XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT" -eq '1' ]] && [[ "$FORCE" -eq '0' ]] && [[ "$REINSTALL" -eq '0' ]]; then
    if [[ "$NO_RESTART" -eq '0' ]]; then
      if [[ "$XRAY_RUNNING" -eq '1' ]]; then
        start_xray
      fi
    else
      if [[ "$XRAY_RUNNING" -eq '1' ]]; then
        echo "${red}Xray has been installed but a service restart is required."
        echo "${red}To prevent inconsistency, manually restart the service as soon as possible.${reset}"
      fi
    fi
  else
    systemctl start xray
    systemctl enable xray
    sleep 1s
    if systemctl -q is-active xray; then
      echo "info: Enable and start the Xray service"
    else
      echo "warning: Failed to enable and start the Xray service"
    fi
  fi
}

main "$@"
