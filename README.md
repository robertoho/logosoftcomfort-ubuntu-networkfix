# LOGO! Soft Comfort Network Adapter Fix

`apply-network-adapter-fix.sh` patches LOGO! Soft Comfort to recognize network adapters correctly on modern Linux distributions. It rebuilds the problematic Java classes with a more resilient implementation that supports predictable DHCP detection on Debian/Ubuntu systems and other distributions using the `/etc/sysconfig` layout.

## What the script does
- Validates the LOGO! Soft Comfort installation directory.
- Compiles patched Java sources that extend the original Siemens classes.
- Installs the rebuilt `.class` files in place, preserving everything else.
- Cleans up all temporary build artifacts automatically.

## Prerequisites
- LOGO! Soft Comfort already installed (tested with the bundled Oracle JRE).
- bash and the bundled `javac` shipped with LOGO! Soft Comfort.
- Linux system with write access to the installation directory.

## Usage
```bash
./apply-network-adapter-fix.sh /path/to/LOGOComfort
```

- Pass the LOGO! Soft Comfort installation directory explicitly, or omit the argument to use the current working directory.
- The script exits if required files are missing, so you can safely re-run it after updates.
- When it prints `Network adapter fix applied`, the patched classes are in place and the application can be launched normally.

## Why this matters
Recent Ubuntu-based distributions renamed network adapters (for example, `enp0s31f6` instead of `eth0`). LOGO! Soft Comfort's original `NetworkAdapterSuseUtil` class only looked for legacy names and failed to detect DHCP. This patch adds a smarter lookup that understands modern naming schemes while keeping compatibility with the original behavior.

## License
Released under the MIT License. See [`LICENSE`](LICENSE) for full details. You are free to use, modify, and redistribute this project without restriction.
# logosoftcomfort-ubuntu-networkfix
