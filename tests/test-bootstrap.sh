#!/usr/bin/env bash
set -euo pipefail

: "${DROID_UID:=10377}"
: "${DROID_GID:=10377}"
: "${PACKAGE_NAME:=com.termux.nix}"
: "${APP_FILES:=/data/data/${PACKAGE_NAME}/files}"
: "${INSTALLATION_DIR:=${APP_FILES}/usr}"

NIX_BUILD=(nix build --no-link --print-out-paths --impure)
BASH_BIN=$(${NIX_BUILD[@]} .#pkgsStatic.bash.out)/bin/bash
BSDTAR_BIN=$(${NIX_BUILD[@]} .#libarchive.out)/bin/bsdtar
SED_BIN=$(${NIX_BUILD[@]} .#pkgsStatic.gnused.out)/bin/sed
BWRAP_BIN=$(${NIX_BUILD[@]} .#bubblewrap.out)/bin/bwrap
PROCPS=$(${NIX_BUILD[@]} .#pkgsStatic.procps.out)
COREUTILS=$(${NIX_BUILD[@]} .#pkgsStatic.coreutils.out)
BOOTSTRAP_ZIP=$(find "$(${NIX_BUILD[@]} .#bootstrap-zip)" -maxdepth 1 -name "*.zip" -type f 2>/dev/null | head -n1)

WORKSPACE=$(mktemp --directory --tmpdir android-sim.XXXXXXXXXX)
trap 'echo "[LOG] Cleaning up workspace: ${WORKSPACE}"; sudo rm -rf "${WORKSPACE}"' EXIT

echo "[LOG] Creating simulated Android directory structure"
mkdir --parents "${WORKSPACE}/system/bin" \
	"${WORKSPACE}/system/etc" \
	"${WORKSPACE}/system/lib" \
	"${WORKSPACE}/system/lib64" \
	"${WORKSPACE}/system/usr" \
	"${WORKSPACE}/data/local/tmp" \
	"${WORKSPACE}${APP_FILES}/home"

chmod --recursive 0755 "${WORKSPACE}"
chmod 1777 "${WORKSPACE}/data/local/tmp"

cp --force --dereference "${BASH_BIN}" "${WORKSPACE}/system/bin/sh"
cp --force --dereference "${BASH_BIN}" "${WORKSPACE}/system/bin/bash"
chmod +x "${WORKSPACE}/system/bin/sh" "${WORKSPACE}/system/bin/bash"
cp --force --dereference "${SED_BIN}" "${WORKSPACE}/system/bin/sed"
chmod +x "${WORKSPACE}/system/bin/sed"

for cmd in env ls cat mv rm cp mkdir chmod chown ln id whoami pwd stat tail head dirname basename readlink true false printenv; do
	cp --force --dereference "${COREUTILS}/bin/${cmd}" "${WORKSPACE}/system/bin/${cmd}"
	chmod +x "${WORKSPACE}/system/bin/${cmd}"
done

cp --force --dereference "${PROCPS}/bin/ps" "${WORKSPACE}/system/bin/ps"
chmod +x "${WORKSPACE}/system/bin/ps"
cp --force --dereference "${PROCPS}/bin/pgrep" "${WORKSPACE}/system/bin/pgrep"
chmod +x "${WORKSPACE}/system/bin/pgrep"

cat >"${WORKSPACE}/system/etc/passwd" <<EOF
root:x:0:0:root:${INSTALLATION_DIR}/root:/system/bin/sh
nix-on-droid:x:${DROID_UID}:${DROID_GID}:nix-on-droid:${APP_FILES}/home:/system/bin/sh
EOF
echo "nix-on-droid:x:${DROID_GID}:" >"${WORKSPACE}/system/etc/group"

echo "[LOG] Extracting bootstrap archive"
mkdir --parents "${WORKSPACE}${INSTALLATION_DIR}/"
"${BSDTAR_BIN}" -xf "${BOOTSTRAP_ZIP}" -C "${WORKSPACE}${INSTALLATION_DIR}/" --no-same-permissions --no-same-owner
sudo chattr -i -R "${WORKSPACE}${INSTALLATION_DIR}"
chmod --recursive u+w "${WORKSPACE}${INSTALLATION_DIR}"

cp --recursive ${WORKSPACE}/system/etc ${WORKSPACE}/etc

NIX_CONF_DIR="${WORKSPACE}${APP_FILES}/home/.config/nix"
mkdir --parents "${NIX_CONF_DIR}"
cat >"${NIX_CONF_DIR}/nix.conf" <<EOF
access-tokens = github.com=${GITHUB_TOKEN:-}
build-users-group =
sandbox = false
allow-unsafe-native-code-during-evaluation = true
experimental-features = nix-command flakes
max-jobs = 1
cores = 1
EOF

sudo chown --recursive 0:0 "${WORKSPACE}${INSTALLATION_DIR}"
sudo chown --recursive 0:0 "${WORKSPACE}/data"

BWRAP_CMD=(sudo "${BWRAP_BIN}" --unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup --unshare-user --uid "${DROID_UID}" --gid "${DROID_GID}" --hostname android-sim)

echo "[LOG] Launching Android bwrap sandbox and executing nix-on-droid login"
exec "${BWRAP_CMD[@]}" \
	--tmpfs /storage \
	--tmpfs /vendor \
	--tmpfs /mnt \
	--bind "${WORKSPACE}/system" /system \
	--bind "${WORKSPACE}/data" /data \
	--bind "${WORKSPACE}/etc" /etc \
	--proc /proc \
	--dev /dev \
	--setenv PATH "/system/bin:/system/xbin:/data/local/bin:${INSTALLATION_DIR}/bin" \
	--setenv ANDROID_DATA "/data" \
	--setenv ANDROID_ROOT "/system" \
	--setenv ANDROID_VERSION "14" \
	--setenv ANDROID_SDK "34" \
	--setenv ANDROID_ART_ROOT "/system/bin/art" \
	--setenv ANDROID_I18N_ROOT "/system/usr" \
	--setenv ANDROID_RUNTIME_ROOT "/system" \
	--setenv ANDROID_TZDATA_ROOT "/system/usr/share/zoneinfo" \
	--setenv HOME "${APP_FILES}/home" \
	--setenv USER "nix-on-droid" \
	--setenv TERM "xterm-256color" \
	--setenv TMPDIR "${INSTALLATION_DIR}/tmp" \
	--setenv TEMP "${INSTALLATION_DIR}/tmp" \
	--setenv EXTERNAL_STORAGE "/sdcard" \
	--setenv ANDROID_ASSETS "assets" \
	--setenv ANDROID_PRIVATE "/data/data/${PACKAGE_NAME}" \
	--setenv LD_LIBRARY_PATH "/system/lib64:/system/lib" \
	--setenv LANG "C" \
	--setenv LC_ALL "C" \
	--setenv PROOT_NO_SECCOMP "1" \
	--setenv TERMUX_VERSION "0.118.0" \
	--setenv TERMUX_APP_PACKAGE "${PACKAGE_NAME}" \
	--setenv TERMUX_PREFIX "${INSTALLATION_DIR}" \
	--setenv TERMUX_HOME "${APP_FILES}/home" \
	--setenv PREFIX "${INSTALLATION_DIR}" \
	--setenv ANDROID_DATA_ROOT "/data" \
	--setenv ANDROID_CACHE "/data/data/${PACKAGE_NAME}/cache" \
	--setenv ANDROID_SOCKET "unix" \
	--setenv NIX_REMOTE "" \
	--setenv NIX_CONF_DIR "${APP_FILES}/home/.config/nix" \
	/system/bin/sh -c "
        set -euo pipefail
        cd ${INSTALLATION_DIR}
        
        EXEC_TXT=\"${INSTALLATION_DIR}/EXECUTABLES.txt\"
        echo \"[LOG] Restoring executable permissions configured in \$EXEC_TXT\"
        while IFS= read -r p || [[ -n \"\$p\" ]]; do
            [[ -z \"\$p\" ]] && continue
            t=\"${INSTALLATION_DIR}/\${p#/}\"
            [[ -e \"\$t\" ]] && chmod 0755 \"\$t\"
        done <\"\$EXEC_TXT\"
            
        SYM_TXT=\"${INSTALLATION_DIR}/SYMLINKS.txt\"
        echo \"[LOG] Restoring symlinks from \$SYM_TXT\"
        while IFS= read -r l || [[ -n \"\$l\" ]]; do
            [[ -z \"\$l\" ]] && continue
            tgt=\"\${l%←*}\"
            lnk=\"\${l#*←}\"
            abs_lnk=\"${INSTALLATION_DIR}/\${lnk#/}\"
            mkdir --parents \"\$(dirname \"\$abs_lnk\")\"
            rm --force \"\$abs_lnk\"
            ln --symbolic --force \"\$tgt\" \"\$abs_lnk\"
        done <\"\$SYM_TXT\"
        
        chmod 0555 /

        exec ${INSTALLATION_DIR}/bin/login
    "
