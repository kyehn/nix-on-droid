#!/usr/bin/env bash
# Regression guard for the remote caches.
#
# A cache that is only listed under `substituters` is ignored by Nix for the
# unprivileged `nix-on-droid` user, and every build silently degrades into a
# from-source build. Every configured cache must therefore also be trusted, and
# must come with its public key.
set -euo pipefail

cd "$(dirname "$0")/.."

nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  configuration = flake.lib.nixOnDroidConfiguration { modules = [ ]; };
in {
  substituters = configuration.config.nix.settings.substituters;
  trustedSubstituters = configuration.config.nix.settings.trusted-substituters;
  trustedPublicKeys = configuration.config.nix.settings.trusted-public-keys;
}
' | python3 -c '
import json
import sys

settings = json.load(sys.stdin)
substituters = settings["substituters"]
trusted_substituters = settings["trustedSubstituters"]
trusted_public_keys = settings["trustedPublicKeys"]

failures = []
if not substituters:
    failures.append("no substituter is configured at all")

for cache in substituters:
    host = cache.removeprefix("https://")
    if cache not in trusted_substituters:
        failures.append(f"{cache} is a substituter but not a trusted substituter")
    if not any(key.startswith(f"{host}-1:") for key in trusted_public_keys):
        failures.append(f"{cache} has no matching entry in trusted-public-keys")

for failure in failures:
    print(f"FAIL: {failure}", file=sys.stderr)

if failures:
    raise SystemExit(1)

print("remote caches are substituters, trusted substituters and keyed: " + " ".join(substituters))
'
