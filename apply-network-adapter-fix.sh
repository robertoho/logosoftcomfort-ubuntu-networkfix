#!/usr/bin/env bash
set -euo pipefail

# Usage: ./apply-network-adapter-fix.sh [/path/to/LOGOComfort]
# Defaults to current directory if no path provided.

TARGET_DIR="${1:-$(pwd)}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Target directory '$TARGET_DIR' does not exist." >&2
    exit 1
fi

cd "$TARGET_DIR"

if [[ ! -x "jre/bin/javac" ]]; then
    echo "javac not found at '$TARGET_DIR/jre/bin/javac'." >&2
    exit 1
fi

if [[ ! -f "lib/classes.jar" ]] || [[ ! -f "lib/jna.jar" ]]; then
    echo "Required jar files missing under '$TARGET_DIR/lib'." >&2
    exit 1
fi

tmp_src_dir=$(mktemp -d "logo_patch_src.XXXX")
tmp_build_dir=$(mktemp -d "logo_patch_build.XXXX")
trap 'rm -rf "$tmp_src_dir" "$tmp_build_dir"' EXIT

mkdir -p "$tmp_src_dir/DE/siemens/ad/logo/util/dipmgr"

cat <<'JAVA' > "$tmp_src_dir/DE/siemens/ad/logo/util/dipmgr/NetworkAdapterUtil.java"
package DE.siemens.ad.logo.util.dipmgr;

import com.sun.jna.Platform;

public class NetworkAdapterUtil {
    private static INetworkAdapterUtil _instance;

    public NetworkAdapterUtil() {
    }

    public static INetworkAdapterUtil getInstance() {
        if (_instance == null) {
            if (Platform.isWindows()) {
                _instance = new NetworkAdapterWindowsUtil();
            } else if (Platform.isLinux()) {
                _instance = new PatchedNetworkAdapterSuseUtil();
            } else if (Platform.isMac()) {
                _instance = new NetworkAdapterMacUtil();
            } else {
                throw new UnsupportedOperationException();
            }
        }
        return _instance;
    }
}
JAVA

cat <<'JAVA' > "$tmp_src_dir/DE/siemens/ad/logo/util/dipmgr/PatchedNetworkAdapterSuseUtil.java"
package DE.siemens.ad.logo.util.dipmgr;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.Locale;

class PatchedNetworkAdapterSuseUtil extends NetworkAdapterSuseUtil {
    PatchedNetworkAdapterSuseUtil() {
        super();
    }

    @Override
    protected boolean readDHCPStatus(String adapterName, String macAddress) {
        File configFile = resolveConfigFile(adapterName, macAddress);
        if (configFile == null || !configFile.exists()) {
            return false;
        }

        try (FileReader reader = new FileReader(configFile);
             BufferedReader bufferedReader = new BufferedReader(reader)) {
            String line;
            while ((line = bufferedReader.readLine()) != null) {
                String normalized = line.toLowerCase(Locale.ROOT);
                if (normalized.startsWith("bootproto") && normalized.contains("dhcp")) {
                    return true;
                }
            }
        } catch (IOException ignored) {
            // Fall back to false if we cannot read the configuration file.
        }

        return false;
    }

    private File resolveConfigFile(String adapterName, String macAddress) {
        if (adapterName == null || adapterName.isEmpty()) {
            return null;
        }

        File primary = new File("/etc/sysconfig/network/ifcfg-" + adapterName);
        if (primary.exists()) {
            return primary;
        }

        String legacyType = mapToLegacyType(adapterName);
        if (legacyType == null || macAddress == null || macAddress.isEmpty()) {
            return null;
        }

        File fallback = new File("/etc/sysconfig/network/ifcfg-" + legacyType + "-id-" + macAddress);
        if (fallback.exists()) {
            return fallback;
        }

        return null;
    }

    private String mapToLegacyType(String adapterName) {
        String lower = adapterName.toLowerCase(Locale.ROOT);
        if (lower.startsWith("eth") || lower.startsWith("en") || lower.startsWith("em")) {
            return "eth";
        }
        if (lower.startsWith("wlan") || lower.startsWith("wl") || lower.startsWith("wifi") || lower.startsWith("wwan")) {
            return "wlan";
        }
        return null;
    }
}
JAVA

./jre/bin/javac -cp "lib/classes.jar:lib/jna.jar" -d "$tmp_build_dir" \
    $(find "$tmp_src_dir" -name '*.java')

install_dir="DE/siemens/ad/logo/util/dipmgr"
mkdir -p "$install_dir"
cp "$tmp_build_dir/$install_dir/NetworkAdapterUtil.class" "$install_dir/"
cp "$tmp_build_dir/$install_dir/PatchedNetworkAdapterSuseUtil.class" "$install_dir/"

echo "Network adapter fix applied in '$TARGET_DIR'."
