#!/usr/bin/env bash
# install-asahi.sh — guided wrapper around the official Asahi installer.
# Run with sudo from a macOS Terminal on the TARGET Mac, AFTER precheck.sh passes.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Asahi guided install =="
echo "Re-running precheck first..."
bash "$HERE/precheck.sh" || { echo "Precheck failed — fix and retry."; exit 1; }

cat <<'NOTE'

When the interactive Asahi installer launches, answer:
  • OS to install ............ Fedora Asahi Remix  ->  Server (headless)
  • Linux partition size ..... disk minus ~80 GB (keep ~80 GB for macOS)
  • Confirm repartition ...... Yes

The installer cannot be fully scripted — answer the prompts at the keyboard.
After it finishes, it will instruct you to reboot into 1TR. See runbook 02.

NOTE
read -r -p "Launch the Asahi installer now? [y/N] " a
[ "$a" = "y" ] || [ "$a" = "Y" ] || { echo "Aborted."; exit 0; }

# Always fetch the current installer command from the official homepage rather than hardcoding a URL.
echo "Fetching the current installer URL from the Asahi homepage..."
echo "If this errors, copy the latest 'curl ... | sh' command from https://asahilinux.org/fedora/"
curl -fsSL "https://alx.sh" | sh
# (alx.sh is Asahi's documented shortlink to the current installer; precheck validated reachability.)

echo
echo "Installer exited. Next: power off and do the 1TR dance (runbook 02)."
read -r -p "Run 'shutdown -h now' for you? [y/N] " s
[ "$s" = "y" ] || [ "$s" = "Y" ] && shutdown -h now || echo "Shut down manually when ready."
