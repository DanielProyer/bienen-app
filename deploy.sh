#!/usr/bin/env bash
# Deploy bienen_app to GitHub Pages (gh-pages branch).
#
# Warum dieses Script: Flutter-Web auf GitHub Pages cached aggressiv.
# index.html + flutter_bootstrap.js werden über ?v=<version> (siehe
# web/index.html) frisch geholt – ABER main.dart.js (der App-Code) wird
# vom Bootstrap OHNE Query geladen und bleibt bis zu 10 Min im Browser-
# Cache. Ergebnis: normaler Refresh zeigt die alte App.
#
# Fix: hier main.dart.js pro Version cache-busten (?v=<version>). Damit
# holt ein normaler Refresh (dank Versions-Check-Redirect in index.html)
# zuverlässig den neuen Code – jetzt und in Zukunft.
#
# Nutzung:  bash deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

VER=$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//; s/+.*//')
echo ">> Building v${VER} (flutter build web) ..."
flutter build web

BOOT=build/web/flutter_bootstrap.js
echo ">> Cache-busting entrypoint (main.dart.js?v=${VER}) ..."
sed -i "s|\"main\.dart\.js\"|\"main.dart.js?v=${VER}\"|g" "$BOOT"
CNT=$(grep -c "main.dart.js?v=${VER}" "$BOOT" || true)
echo "   patched references: ${CNT}"
if [ "${CNT}" -lt 1 ]; then
  echo "!! WARN: entrypoint patch did not apply – Bootstrap-Format geändert? Bitte prüfen."
fi

echo ">> Deploying to gh-pages ..."
WT=$(mktemp -d)
git fetch origin gh-pages
git worktree add "$WT" gh-pages >/dev/null
git -C "$WT" merge --ff-only origin/gh-pages >/dev/null 2>&1 || true
cp -r build/web/. "$WT"/
git -C "$WT" add -A
git -C "$WT" commit -m "Deploy v${VER}" >/dev/null 2>&1 || echo "   (nothing new to deploy)"
git -C "$WT" push origin gh-pages
git worktree remove "$WT"
git worktree prune
echo ">> Deployed v${VER}. (main.dart.js ist versioniert → normaler Refresh reicht.)"
